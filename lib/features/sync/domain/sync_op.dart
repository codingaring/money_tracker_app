// Design Ref: §3.1 sync_queue.op CHECK constraint — stored as text enum.

enum SyncOp {
  insert,
  update,
  delete,
}
