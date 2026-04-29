// Design Ref: §3.4, §4.6 — sync_queue CRUD for transactions sheet sync.

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../../core/db/tables.dart';

part 'sync_queue_dao.g.dart';

@DriftAccessor(tables: [SyncQueue])
class SyncQueueDao extends DatabaseAccessor<AppDatabase>
    with _$SyncQueueDaoMixin {
  SyncQueueDao(super.db);

  /// Returns the inserted queue id. Caller usually doesn't need it.
  Future<int> enqueue(SyncQueueCompanion data) {
    return into(syncQueue).insert(data);
  }

  /// FIFO drain — oldest enqueued first.
  Future<List<SyncQueueEntry>> fetchOldest(int limit) {
    return (select(syncQueue)
          ..orderBy([(q) => OrderingTerm.asc(q.id)])
          ..limit(limit))
        .get();
  }

  Future<int> deleteById(int id) {
    return (delete(syncQueue)..where((q) => q.id.equals(id))).go();
  }

  /// Atomically increment attempt_count and record error. Used by SyncService
  /// when a single op fails; the entry stays in the queue for retry.
  ///
  /// last_attempt_at must be Unix epoch (INT) to match Drift's default
  /// DateTime storage — passing an ISO string corrupts the column and reads
  /// later throw FormatException via SqlTypes._readDateTime.
  Future<void> recordAttempt(int id, String error) async {
    await customStatement(
      "UPDATE sync_queue "
      "SET attempt_count = attempt_count + 1, "
      "    last_attempt_at = strftime('%s', 'now'), "
      "    last_error = ? "
      "WHERE id = ?",
      [error, id],
    );
  }

  Stream<int> watchPendingCount() {
    final exp = syncQueue.id.count();
    final query = selectOnly(syncQueue)..addColumns([exp]);
    return query.map((row) => row.read(exp) ?? 0).watchSingle();
  }

  Future<int> readPendingCount() async {
    final exp = syncQueue.id.count();
    final query = selectOnly(syncQueue)..addColumns([exp]);
    final row = await query.getSingle();
    return row.read(exp) ?? 0;
  }

  Future<int> readMaxAttempt() async {
    final exp = syncQueue.attemptCount.max();
    final query = selectOnly(syncQueue)..addColumns([exp]);
    final row = await query.getSingle();
    return row.read(exp) ?? 0;
  }
}
