// Design Ref: §4.2 — SyncService is the single entry point for sync writes.
// Repositories depend on this abstraction, not on a concrete Drift DAO.
// Concrete impl arrives in Module-4 (LocalQueueEnqueuer / SyncService).

import 'sync_op.dart';

abstract class SyncEnqueuer {
  Future<void> enqueue({
    required String localId,
    required SyncOp op,
  });
}
