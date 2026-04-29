// Module-2 unit test — fake SyncEnqueuer used by Repository tests in Module-4.

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/features/sync/domain/sync_enqueuer.dart';
import 'package:money_tracker_app/features/sync/domain/sync_op.dart';

void main() {
  group('SyncOp', () {
    test('enum order matches schema CHECK constraint values', () {
      expect(SyncOp.values.map((e) => e.name), [
        'insert',
        'update',
        'delete',
      ]);
    });
  });

  group('RecordingSyncEnqueuer (test fake)', () {
    test('records every enqueue call in order', () async {
      final fake = RecordingSyncEnqueuer();
      await fake.enqueue(localId: 'a', op: SyncOp.insert);
      await fake.enqueue(localId: 'b', op: SyncOp.update);
      await fake.enqueue(localId: 'a', op: SyncOp.delete);

      expect(fake.calls, [
        (localId: 'a', op: SyncOp.insert),
        (localId: 'b', op: SyncOp.update),
        (localId: 'a', op: SyncOp.delete),
      ]);
    });

    test('throwing variant simulates queue write failure', () async {
      final fake = ThrowingSyncEnqueuer();
      await expectLater(
        fake.enqueue(localId: 'x', op: SyncOp.insert),
        throwsStateError,
      );
    });
  });
}

/// Reusable test fake. Lives in test/ so production code does not depend on it.
class RecordingSyncEnqueuer implements SyncEnqueuer {
  final List<({String localId, SyncOp op})> calls = [];

  @override
  Future<void> enqueue({required String localId, required SyncOp op}) async {
    calls.add((localId: localId, op: op));
  }
}

class ThrowingSyncEnqueuer implements SyncEnqueuer {
  @override
  Future<void> enqueue({required String localId, required SyncOp op}) async {
    throw StateError('simulated queue failure');
  }
}
