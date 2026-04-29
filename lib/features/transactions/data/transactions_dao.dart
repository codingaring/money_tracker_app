// Design Ref: §3.3 + §4.4 + §4.3 (M2 search) — TxRow CRUD + reactive watch.
// Repository wraps this and adds balance-update logic. DAO never touches Sheets.

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables.dart';
import '../domain/transaction.dart';

part 'transactions_dao.g.dart';

@DriftAccessor(tables: [Transactions])
class TransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionsDaoMixin {
  TransactionsDao(super.db);

  /// Reactive non-deleted, newest first. ListScreen + Dashboard 의존.
  Stream<List<TxRow>> watchAll({int? limit}) {
    final q = select(transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    if (limit != null) q.limit(limit);
    return q.watch();
  }

  Future<List<TxRow>> readAll({bool includeDeleted = false}) {
    final q = select(transactions);
    if (!includeDeleted) {
      q.where((t) => t.deletedAt.isNull());
    }
    q.orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);
    return q.get();
  }

  Future<TxRow?> findByLocalId(String localId) {
    return (select(transactions)..where((t) => t.localId.equals(localId)))
        .getSingleOrNull();
  }

  Future<int> insertOne(TransactionsCompanion data) {
    return into(transactions).insert(data);
  }

  Future<int> updateByLocalId(String localId, TransactionsCompanion patch) {
    return (update(transactions)..where((t) => t.localId.equals(localId)))
        .write(patch.copyWith(updatedAt: Value(DateTime.now())));
  }

  /// Soft delete — sets deleted_at. Hard delete only after Sheets clears the row
  /// (Module-4 SyncService).
  Future<int> softDeleteByLocalId(String localId) {
    return (update(transactions)..where((t) => t.localId.equals(localId)))
        .write(TransactionsCompanion(
      deletedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  Future<int> hardDeleteByLocalId(String localId) {
    return (delete(transactions)..where((t) => t.localId.equals(localId))).go();
  }

  Future<int> markSyncedByLocalId(String localId) {
    return (update(transactions)..where((t) => t.localId.equals(localId)))
        .write(TransactionsCompanion(syncedAt: Value(DateTime.now())));
  }

  /// Plan SC: SC-3 (검색 응답 ≤ 100ms).
  /// Combined keyword + multi-axis filter. memo LIKE is only applied when a
  /// non-empty trimmed [keyword] is provided so the index on
  /// (occurred_at DESC, deleted_at) carries unfiltered queries.
  ///
  /// [accountId] matches OR across from/to so transfers register on either side.
  Future<List<TxRow>> search({
    String? keyword,
    DateTime? from,
    DateTime? to,
    int? accountId,
    int? categoryId,
    TxType? type,
    int limit = 200,
  }) {
    final q = select(transactions)
      ..where((t) => t.deletedAt.isNull());

    final trimmed = keyword?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      q.where((t) => t.memo.like('%$trimmed%'));
    }
    if (from != null) {
      q.where((t) => t.occurredAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      q.where((t) => t.occurredAt.isSmallerThanValue(to));
    }
    if (accountId != null) {
      q.where((t) =>
          t.fromAccountId.equals(accountId) |
          t.toAccountId.equals(accountId));
    }
    if (categoryId != null) {
      q.where((t) => t.categoryId.equals(categoryId));
    }
    if (type != null) {
      q.where((t) => t.type.equalsValue(type));
    }

    q
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
      ..limit(limit);
    return q.get();
  }
}
