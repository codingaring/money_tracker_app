// Design Ref: §4.6 watchStatus — value object reported to Settings UI.

class SyncStatus {
  const SyncStatus({
    required this.pendingCount,
    this.lastSuccessAt,
    this.lastError,
    this.consecutiveFailures = 0,
  });

  /// Rows currently in sync_queue.
  final int pendingCount;

  /// Last successful flush timestamp.
  final DateTime? lastSuccessAt;

  /// Most recent error message (cleared on next success).
  final String? lastError;

  /// Used by Settings UI to show a "재로그인 필요" badge after 5 failures.
  final int consecutiveFailures;

  bool get isHealthy => pendingCount == 0 && consecutiveFailures == 0;

  @override
  String toString() =>
      'SyncStatus(pending=$pendingCount, lastSuccess=$lastSuccessAt, '
      'failures=$consecutiveFailures, error=$lastError)';
}
