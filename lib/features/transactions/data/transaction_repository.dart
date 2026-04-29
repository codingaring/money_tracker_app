// Design Ref: §4.4 — TransactionRepository: 4-type CRUD + atomic balance update.
//
// Plan SC: 잔액 무결성 (FR-04, FR-05, FR-06, FR-18).
//
// **Invariant**: every balance change happens INSIDE a single db.transaction
// alongside the tx row write. AccountsDao is the only path to balance updates.

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../accounts/data/accounts_dao.dart';
import '../../sync/domain/sync_enqueuer.dart';
import '../../sync/domain/sync_op.dart';
import '../domain/delta_calculator.dart';
import '../domain/transaction.dart';
import 'transactions_dao.dart';

class TransactionRepository {
  TransactionRepository({
    required AppDatabase db,
    required AccountsDao accountsDao,
    required SyncEnqueuer sync,
    Uuid? uuidGenerator,
  })  : _db = db,
        _accountsDao = accountsDao,
        _sync = sync,
        _uuid = uuidGenerator ?? const Uuid();

  final AppDatabase _db;
  final AccountsDao _accountsDao;
  final SyncEnqueuer _sync;
  final Uuid _uuid;

  TransactionsDao get _dao => _db.transactionsDao;

  Stream<List<TxRow>> watchAll({int? limit}) => _dao.watchAll(limit: limit);

  /// Plan SC: 5초 입력 — must complete in ≤ 200ms p95.
  Future<TxRow> add(NewTransaction draft) async {
    final violation = draft.validate();
    if (violation != null) throw ArgumentError(violation);

    final localId = _uuid.v4();

    return _db.transaction(() async {
      // valuation needs the current to_account balance to compute its delta.
      final prevBalance = draft.type == TxType.valuation
          ? await _accountsDao.readBalance(draft.toAccountId!)
          : null;
      final deltas = DeltaCalculator.compute(
        type: draft.type,
        amount: draft.amount,
        prevBalanceForValuation: prevBalance,
      );

      await _dao.insertOne(TransactionsCompanion.insert(
        localId: localId,
        type: draft.type,
        amount: draft.amount,
        categoryId: Value(draft.categoryId),
        fromAccountId: Value(draft.fromAccountId),
        toAccountId: Value(draft.toAccountId),
        fromDelta: Value(deltas.fromDelta),
        toDelta: Value(deltas.toDelta),
        memo: Value(draft.memo),
        occurredAt: draft.occurredAt,
      ));

      await _applyDeltas(
        fromId: draft.fromAccountId,
        toId: draft.toAccountId,
        deltas: deltas,
      );

      // Best-effort: enqueue must NOT break the user's save.
      await _safeEnqueue(localId, SyncOp.insert);

      final inserted = await _dao.findByLocalId(localId);
      if (inserted == null) {
        throw StateError('inserted tx not found localId=$localId');
      }
      return inserted;
    });
  }

  /// Atomic: undo old delta → recompute new → apply new → mark unsynced.
  Future<void> update(TxRow row, NewTransaction draft) async {
    final violation = draft.validate();
    if (violation != null) throw ArgumentError(violation);

    await _db.transaction(() async {
      // 1) Undo old effect.
      await _applyDeltas(
        fromId: row.fromAccountId,
        toId: row.toAccountId,
        deltas: TxDeltas(fromDelta: row.fromDelta, toDelta: row.toDelta),
        invert: true,
      );

      // 2) Compute new (post-undo balance for valuation).
      final prevBalance = draft.type == TxType.valuation
          ? await _accountsDao.readBalance(draft.toAccountId!)
          : null;
      final newDeltas = DeltaCalculator.compute(
        type: draft.type,
        amount: draft.amount,
        prevBalanceForValuation: prevBalance,
      );

      // 3) Persist new tx state.
      await _dao.updateByLocalId(
        row.localId,
        TransactionsCompanion(
          type: Value(draft.type),
          amount: Value(draft.amount),
          categoryId: Value(draft.categoryId),
          fromAccountId: Value(draft.fromAccountId),
          toAccountId: Value(draft.toAccountId),
          fromDelta: Value(newDeltas.fromDelta),
          toDelta: Value(newDeltas.toDelta),
          memo: Value(draft.memo),
          occurredAt: Value(draft.occurredAt),
          syncedAt: const Value(null),
        ),
      );

      await _applyDeltas(
        fromId: draft.fromAccountId,
        toId: draft.toAccountId,
        deltas: newDeltas,
      );

      await _safeEnqueue(row.localId, SyncOp.update);
    });
  }

  /// Soft delete — undo deltas, mark deleted_at, enqueue clear.
  Future<void> delete(String localId) async {
    await _db.transaction(() async {
      final row = await _dao.findByLocalId(localId);
      if (row == null) return; // idempotent

      await _applyDeltas(
        fromId: row.fromAccountId,
        toId: row.toAccountId,
        deltas: TxDeltas(fromDelta: row.fromDelta, toDelta: row.toDelta),
        invert: true,
      );

      await _dao.softDeleteByLocalId(localId);
      await _safeEnqueue(localId, SyncOp.delete);
    });
  }

  Future<void> _applyDeltas({
    required int? fromId,
    required int? toId,
    required TxDeltas deltas,
    bool invert = false,
  }) async {
    final from = invert
        ? (deltas.fromDelta == null ? null : -deltas.fromDelta!)
        : deltas.fromDelta;
    final to = invert
        ? (deltas.toDelta == null ? null : -deltas.toDelta!)
        : deltas.toDelta;

    if (from != null && fromId != null) {
      await _accountsDao.adjustBalance(fromId, from);
    }
    if (to != null && toId != null) {
      await _accountsDao.adjustBalance(toId, to);
    }
  }

  Future<void> _safeEnqueue(String localId, SyncOp op) async {
    try {
      await _sync.enqueue(localId: localId, op: op);
    } catch (_) {
      // Design §4.4 — enqueue failure must not break the user save.
    }
  }
}
