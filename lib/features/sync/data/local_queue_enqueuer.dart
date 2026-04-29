// Design Ref: §4.6 — Concrete SyncEnqueuer that writes to sync_queue.
//
// **Transaction propagation**: when called from inside an outer
// `db.transaction(...)` (e.g., TransactionRepository.add), this insert runs
// within that transaction (Drift zone-based propagation). Failure rolls back
// the entire user save — but TransactionRepository._safeEnqueue swallows
// exceptions, so a queue write failure does NOT bubble up. SyncService.flush
// includes an orphan scan to recover any tx with synced_at IS NULL but no
// queue entry.

import '../../../core/db/app_database.dart';
import '../domain/sync_enqueuer.dart';
import '../domain/sync_op.dart';
import 'sync_queue_dao.dart';

class LocalQueueEnqueuer implements SyncEnqueuer {
  LocalQueueEnqueuer(this._dao);

  final SyncQueueDao _dao;

  @override
  Future<void> enqueue({required String localId, required SyncOp op}) async {
    await _dao.enqueue(SyncQueueCompanion.insert(
      localId: localId,
      op: op,
    ));
  }
}
