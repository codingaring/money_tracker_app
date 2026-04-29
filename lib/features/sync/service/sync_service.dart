// Design Ref: §4.6 — 3-sheet flush orchestration.
//
// Responsibilities:
//   1. Drain sync_queue → transactions sheet (append/update/clear)
//   2. Snapshot all accounts → accounts sheet (overwrite)
//   3. Aggregate last 12 months → monthly_summary sheet (overwrite)
//   4. Maintain kv_store sync timestamps + SyncStatus stream
//
// **Boundary**: Repositories never call Sheets directly. All Sheets I/O routes
// through this service.

import 'dart:async';

import '../../../core/db/app_database.dart';
import '../../../infrastructure/sheets/sheet_layout.dart';
import '../../../infrastructure/sheets/sheets_client.dart';
import '../../accounts/data/accounts_dao.dart';
import '../../auth/data/google_auth_service.dart';
import '../../templates/data/templates_dao.dart';
import '../../transactions/data/transactions_dao.dart';
import '../data/sync_queue_dao.dart';
import '../domain/sync_op.dart';
import '../domain/sync_status.dart';
import 'monthly_aggregator.dart';

class SyncFlushResult {
  const SyncFlushResult({
    this.txAppended = 0,
    this.txUpdated = 0,
    this.txCleared = 0,
    this.accountsSynced = false,
    this.monthlySynced = false,
    this.templatesSynced = false,
    this.error,
    this.skippedReason,
  });

  factory SyncFlushResult.skipped(String reason) =>
      SyncFlushResult(skippedReason: reason);

  factory SyncFlushResult.failed(Object e) =>
      SyncFlushResult(error: e.toString());

  final int txAppended;
  final int txUpdated;
  final int txCleared;
  final bool accountsSynced;
  final bool monthlySynced;

  /// Plan SC: FR-44 — M3 templates 시트 push 결과.
  final bool templatesSynced;

  final String? error;
  final String? skippedReason;

  bool get isSuccess => error == null && skippedReason == null;

  @override
  String toString() => 'SyncFlushResult('
      'tx +$txAppended ~$txUpdated -$txCleared, '
      'accounts=$accountsSynced, monthly=$monthlySynced, '
      'templates=$templatesSynced, '
      'error=$error, skipped=$skippedReason)';
}

class SyncService {
  SyncService({
    required AppDatabase db,
    required AccountsDao accountsDao,
    required TransactionsDao transactionsDao,
    required TemplatesDao templatesDao,
    required SyncQueueDao queueDao,
    required SheetsClient sheets,
    required GoogleAuthService auth,
  })  : _db = db,
        _accountsDao = accountsDao,
        _txDao = transactionsDao,
        _templatesDao = templatesDao,
        _queueDao = queueDao,
        _sheets = sheets,
        _auth = auth;

  final AppDatabase _db;
  final AccountsDao _accountsDao;
  final TransactionsDao _txDao;
  final TemplatesDao _templatesDao;
  final SyncQueueDao _queueDao;
  final SheetsClient _sheets;
  final GoogleAuthService _auth;

  static const _spreadsheetIdKey = 'spreadsheet_id';
  static const _lastSyncAtKey = 'last_sync_at';
  static const _lastAccountsSyncAtKey = 'last_accounts_sync_at';
  static const _lastMonthlySyncAtKey = 'last_monthly_sync_at';
  static const _lastTemplatesSyncAtKey = 'last_templates_sync_at';
  static const _consecutiveFailuresKey = 'sync_consecutive_failures';

  /// Reactive status — pendingCount streams from the queue table; lastSuccess
  /// and consecutiveFailures are read from kv_store on each emit.
  Stream<SyncStatus> watchStatus() {
    return _queueDao.watchPendingCount().asyncMap((pending) async {
      return SyncStatus(
        pendingCount: pending,
        lastSuccessAt: await _readDateTime(_lastSyncAtKey),
        consecutiveFailures: int.tryParse(
              await _readKv(_consecutiveFailuresKey) ?? '0',
            ) ??
            0,
      );
    });
  }

  Future<SyncFlushResult> flush() async {
    if (!await _auth.isSignedIn()) {
      return SyncFlushResult.skipped('not signed in');
    }

    try {
      // 1. Ensure spreadsheet + 3 sheets + headers.
      final spreadsheetId = await _ensureSpreadsheet();

      // 2. Drain transactions queue.
      final pending = await _queueDao.fetchOldest(50);
      var appended = 0, updated = 0, cleared = 0;
      for (final entry in pending) {
        try {
          final result = await _processQueueEntry(spreadsheetId, entry);
          appended += result.$1;
          updated += result.$2;
          cleared += result.$3;
          await _queueDao.deleteById(entry.id);
        } catch (e) {
          await _queueDao.recordAttempt(entry.id, e.toString());
          // Continue with next entry — partial flush is fine.
        }
      }

      // 3. accounts snapshot — overwrite (design §4.6).
      var accountsSynced = false;
      try {
        await _pushAccountsSnapshot(spreadsheetId);
        await _writeKv(
          _lastAccountsSyncAtKey,
          DateTime.now().toIso8601String(),
        );
        accountsSynced = true;
      } catch (_) {
        // Partial OK — not fatal.
      }

      // 4. monthly_summary aggregate — last 12 months.
      var monthlySynced = false;
      try {
        await _pushMonthlySummary(spreadsheetId);
        await _writeKv(
          _lastMonthlySyncAtKey,
          DateTime.now().toIso8601String(),
        );
        monthlySynced = true;
      } catch (_) {
        // Partial OK.
      }

      // 5. templates snapshot — M3 신규.
      var templatesSynced = false;
      try {
        await _pushTemplatesSnapshot(spreadsheetId);
        await _writeKv(
          _lastTemplatesSyncAtKey,
          DateTime.now().toIso8601String(),
        );
        templatesSynced = true;
      } catch (_) {
        // Partial OK.
      }

      await _writeKv(_lastSyncAtKey, DateTime.now().toIso8601String());
      await _writeKv(_consecutiveFailuresKey, '0');

      return SyncFlushResult(
        txAppended: appended,
        txUpdated: updated,
        txCleared: cleared,
        accountsSynced: accountsSynced,
        monthlySynced: monthlySynced,
        templatesSynced: templatesSynced,
      );
    } catch (e) {
      await _bumpFailureCount();
      return SyncFlushResult.failed(e);
    }
  }

  Future<String> _ensureSpreadsheet() async {
    var id = await _readKv(_spreadsheetIdKey);
    if (id == null || id.isEmpty) {
      id = await _sheets.createSpreadsheet();
      await _writeKv(_spreadsheetIdKey, id);
    }
    await _sheets.ensureSheet(id, SheetLayout.txSheet, SheetLayout.txHeader);
    await _sheets.ensureSheet(
      id,
      SheetLayout.accountsSheet,
      SheetLayout.accountsHeader,
    );
    await _sheets.ensureSheet(
      id,
      SheetLayout.monthlySheet,
      SheetLayout.monthlyHeader,
    );
    // M3 — templates 시트 ensure (기존 사용자도 첫 sync에서 자동 생성).
    await _sheets.ensureSheet(
      id,
      SheetLayout.templatesSheet,
      SheetLayout.templatesHeader,
    );
    return id;
  }

  /// Returns (appended, updated, cleared) deltas for one queue entry.
  Future<(int, int, int)> _processQueueEntry(
    String spreadsheetId,
    SyncQueueEntry entry,
  ) {
    return switch (entry.op) {
      SyncOp.insert => _processInsert(spreadsheetId, entry),
      SyncOp.update => _processUpdate(spreadsheetId, entry),
      SyncOp.delete => _processDelete(spreadsheetId, entry),
    };
  }

  Future<(int, int, int)> _processInsert(
    String spreadsheetId,
    SyncQueueEntry entry,
  ) async {
    final row = await _txDao.findByLocalId(entry.localId);
    if (row == null) return (0, 0, 0); // tx already deleted, skip
    await _sheets.appendRows(
      spreadsheetId,
      SheetLayout.txAppendRange,
      [await _txToRow(row)],
    );
    await _txDao.markSyncedByLocalId(entry.localId);
    return (1, 0, 0);
  }

  Future<(int, int, int)> _processUpdate(
    String spreadsheetId,
    SyncQueueEntry entry,
  ) async {
    final row = await _txDao.findByLocalId(entry.localId);
    if (row == null) return (0, 0, 0);
    final rowIndex = await _sheets.findRowByLocalId(
      spreadsheetId,
      SheetLayout.txIdSearchRange,
      entry.localId,
    );
    if (rowIndex == null) {
      // Never appended — degrade to insert.
      await _sheets.appendRows(
        spreadsheetId,
        SheetLayout.txAppendRange,
        [await _txToRow(row)],
      );
      await _txDao.markSyncedByLocalId(entry.localId);
      return (1, 0, 0);
    }
    await _sheets.updateRow(
      spreadsheetId,
      SheetLayout.txRowRange(rowIndex),
      await _txToRow(row),
    );
    await _txDao.markSyncedByLocalId(entry.localId);
    return (0, 1, 0);
  }

  Future<(int, int, int)> _processDelete(
    String spreadsheetId,
    SyncQueueEntry entry,
  ) async {
    final rowIndex = await _sheets.findRowByLocalId(
      spreadsheetId,
      SheetLayout.txIdSearchRange,
      entry.localId,
    );
    if (rowIndex != null) {
      await _sheets.clearRange(
        spreadsheetId,
        SheetLayout.txRowRange(rowIndex),
      );
    }
    // Hard delete the soft-deleted row only after Sheets confirms.
    await _txDao.hardDeleteByLocalId(entry.localId);
    return (0, 0, rowIndex == null ? 0 : 1);
  }

  Future<void> _pushAccountsSnapshot(String spreadsheetId) async {
    final allAccounts = await _accountsDao.readAll();
    final parentNameById = <int, String>{
      for (final a in allAccounts) a.id: a.name,
    };
    final values = <List<Object?>>[
      SheetLayout.accountsHeader,
      ...allAccounts.map((a) => _accountToRow(a, parentNameById)),
    ];
    await _sheets.overwriteRange(
      spreadsheetId,
      SheetLayout.accountsOverwriteRange,
      values,
    );
  }

  /// Plan SC: FR-44 — templates snapshot push. accounts/monthly 패턴 동일.
  Future<void> _pushTemplatesSnapshot(String spreadsheetId) async {
    final all = await _templatesDao.readAll();
    final accounts = await _accountsDao.readAll();
    final accountNameById = {for (final a in accounts) a.id: a.name};
    final categories = await _db.select(_db.categories).get();
    final categoryNameById = {for (final c in categories) c.id: c.name};

    final values = <List<Object?>>[
      SheetLayout.templatesHeader,
      ...all.map((t) =>
          _templateToRow(t, accountNameById, categoryNameById)),
    ];
    await _sheets.overwriteRange(
      spreadsheetId,
      SheetLayout.templatesOverwriteRange,
      values,
    );
  }

  List<Object?> _templateToRow(
    TxTemplate t,
    Map<int, String> accountNameById,
    Map<int, String> categoryNameById,
  ) =>
      [
        t.name,
        t.type.name,
        t.amount ?? '',
        t.fromAccountId == null
            ? ''
            : (accountNameById[t.fromAccountId!] ?? ''),
        t.toAccountId == null
            ? ''
            : (accountNameById[t.toAccountId!] ?? ''),
        t.categoryId == null
            ? ''
            : (categoryNameById[t.categoryId!] ?? ''),
        t.memo ?? '',
        t.sortOrder,
        t.lastUsedAt?.toIso8601String() ?? '',
      ];

  Future<void> _pushMonthlySummary(String spreadsheetId) async {
    final allTx = await _txDao.readAll();
    final allAccounts = await _accountsDao.readAll();
    final summaries = MonthlyAggregator.compute(
      transactions: allTx,
      accounts: allAccounts,
      months: 12,
    );
    final values = <List<Object?>>[
      SheetLayout.monthlyHeader,
      ...summaries.map(_monthlyToRow),
    ];
    await _sheets.overwriteRange(
      spreadsheetId,
      SheetLayout.monthlyOverwriteRange,
      values,
    );
  }

  // ── Row mapping ──────────────────────────────────────────────────────────

  Future<List<Object?>> _txToRow(TxRow tx) async {
    String? categoryName;
    String? parentCategoryName;
    if (tx.categoryId != null) {
      final cat = await (_db.select(_db.categories)
            ..where((c) => c.id.equals(tx.categoryId!)))
          .getSingleOrNull();
      categoryName = cat?.name;
      // M3: parent name lookup. parent NULL이면 leaf 자체 (단순화).
      if (cat?.parentCategoryId != null) {
        final parent = await (_db.select(_db.categories)
              ..where((c) => c.id.equals(cat!.parentCategoryId!)))
            .getSingleOrNull();
        parentCategoryName = parent?.name;
      } else if (cat != null) {
        parentCategoryName = cat.name; // leaf가 자기 자신이 대분류
      }
    }
    String? fromName;
    if (tx.fromAccountId != null) {
      fromName = (await _accountsDao.findById(tx.fromAccountId!))?.name;
    }
    String? toName;
    if (tx.toAccountId != null) {
      toName = (await _accountsDao.findById(tx.toAccountId!))?.name;
    }
    return [
      tx.occurredAt.toIso8601String(),
      tx.type.name,
      tx.amount,
      parentCategoryName ?? '', // M3: D = category_parent
      categoryName ?? '',
      fromName ?? '',
      toName ?? '',
      tx.memo ?? '',
      tx.localId,
      tx.syncedAt?.toIso8601String() ?? '',
    ];
  }

  List<Object?> _accountToRow(Account a, Map<int, String> parentNameById) {
    return [
      a.name,
      a.type.name,
      a.balance,
      a.parentAccountId == null ? '' : (parentNameById[a.parentAccountId!] ?? ''),
      a.isActive,
      a.updatedAt.toIso8601String(),
      // Design Ref: M2 §8.1 — due_day column. Empty for non-credit_card.
      a.dueDay ?? '',
    ];
  }

  List<Object?> _monthlyToRow(MonthlySummary m) =>
      [m.yearMonth, m.income, m.expense, m.net, m.netWorthEnd];

  // ── kv_store helpers ─────────────────────────────────────────────────────

  Future<String?> _readKv(String key) async {
    final row = await (_db.select(_db.kvStore)..where((k) => k.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _writeKv(String key, String value) async {
    await _db.into(_db.kvStore).insertOnConflictUpdate(
          KvStoreCompanion.insert(key: key, value: value),
        );
  }

  Future<DateTime?> _readDateTime(String key) async {
    final s = await _readKv(key);
    return s == null ? null : DateTime.tryParse(s);
  }

  Future<void> _bumpFailureCount() async {
    final cur = int.tryParse(await _readKv(_consecutiveFailuresKey) ?? '0') ?? 0;
    await _writeKv(_consecutiveFailuresKey, (cur + 1).toString());
  }
}
