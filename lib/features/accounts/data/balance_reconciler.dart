// Plan SC: FR-18 — 잔액 무결성 검증.
//
// Strategy: store each account's initial balance in kv_store on creation
// (`account_initial_balance:{id}`). The reconciler then verifies:
//
//   account.balance == initialBalance + sum(deltas applied to account)
//
// Drift = atomic balance update was broken somewhere (the buggy customStatement
// pattern from earlier sanity-check, or future regressions).
//
// First-run backfill: accounts created before this feature have no kv entry.
// We backfill `currentBalance - sumOfDeltas` so subsequent runs detect drift
// (current run always reports clean for those — documented in UI).

import '../../../core/db/app_database.dart';
import 'accounts_dao.dart';

class BalanceDrift {
  const BalanceDrift({
    required this.accountId,
    required this.accountName,
    required this.storedBalance,
    required this.initialBalance,
    required this.sumOfDeltas,
    required this.txCount,
    required this.backfilled,
  });

  final int accountId;
  final String accountName;
  final int storedBalance;
  final int initialBalance;
  final int sumOfDeltas;
  final int txCount;

  /// True when initial balance was missing and we just backfilled.
  /// Such accounts cannot show drift this run; flag for user awareness.
  final bool backfilled;

  int get expectedBalance => initialBalance + sumOfDeltas;
  int get drift => storedBalance - expectedBalance;
  bool get hasDrift => drift != 0;
}

class BalanceReconcileResult {
  const BalanceReconcileResult({
    required this.reports,
    required this.driftCount,
    required this.backfilledCount,
  });

  final List<BalanceDrift> reports;
  final int driftCount;
  final int backfilledCount;

  bool get isClean => driftCount == 0;
}

class BalanceReconciler {
  BalanceReconciler({
    required AppDatabase db,
    required AccountsDao accountsDao,
  })  : _db = db,
        _accountsDao = accountsDao;

  final AppDatabase _db;
  final AccountsDao _accountsDao;

  static const String kvPrefix = 'account_initial_balance:';

  /// Records the opening balance for [accountId]. Idempotent — overwrites.
  /// Called from AccountRepository.create.
  Future<void> recordInitialBalance(int accountId, int amount) async {
    await _db.into(_db.kvStore).insertOnConflictUpdate(
          KvStoreCompanion.insert(
            key: '$kvPrefix$accountId',
            value: amount.toString(),
          ),
        );
  }

  Future<BalanceReconcileResult> compute({bool backfillMissing = true}) async {
    final accounts = await _accountsDao.readAll();
    final txs = await _db.transactionsDao.readAll();

    // Sum of deltas per account.
    final deltas = <int, int>{};
    final txCounts = <int, int>{};
    for (final tx in txs) {
      if (tx.fromAccountId != null && tx.fromDelta != null) {
        deltas.update(
          tx.fromAccountId!,
          (v) => v + tx.fromDelta!,
          ifAbsent: () => tx.fromDelta!,
        );
        txCounts.update(tx.fromAccountId!, (v) => v + 1, ifAbsent: () => 1);
      }
      if (tx.toAccountId != null && tx.toDelta != null) {
        deltas.update(
          tx.toAccountId!,
          (v) => v + tx.toDelta!,
          ifAbsent: () => tx.toDelta!,
        );
        txCounts.update(tx.toAccountId!, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    var driftCount = 0;
    var backfilledCount = 0;
    final reports = <BalanceDrift>[];

    for (final a in accounts) {
      final stored = await _readInitialBalance(a.id);
      var initial = stored;
      var backfilled = false;

      if (stored == null) {
        if (!backfillMissing) {
          // Skip — the account has no baseline, can't compute drift.
          continue;
        }
        // Backfill: assume current is correct as "implied initial + deltas".
        initial = a.balance - (deltas[a.id] ?? 0);
        await recordInitialBalance(a.id, initial);
        backfilled = true;
        backfilledCount++;
      }

      final report = BalanceDrift(
        accountId: a.id,
        accountName: a.name,
        storedBalance: a.balance,
        initialBalance: initial!,
        sumOfDeltas: deltas[a.id] ?? 0,
        txCount: txCounts[a.id] ?? 0,
        backfilled: backfilled,
      );
      if (report.hasDrift) driftCount++;
      reports.add(report);
    }

    return BalanceReconcileResult(
      reports: reports,
      driftCount: driftCount,
      backfilledCount: backfilledCount,
    );
  }

  Future<int?> _readInitialBalance(int accountId) async {
    final row = await (_db.select(_db.kvStore)
          ..where((k) => k.key.equals('$kvPrefix$accountId')))
        .getSingleOrNull();
    if (row == null) return null;
    return int.tryParse(row.value);
  }
}
