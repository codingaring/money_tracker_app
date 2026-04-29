// Plan SC: FR-18 — pure-logic test of BalanceDrift / BalanceReconcileResult.
// Real DB-backed reconciler tests deferred (require sqlite native binary).

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/features/accounts/data/balance_reconciler.dart';

void main() {
  group('BalanceDrift', () {
    test('expectedBalance = initial + sumOfDeltas', () {
      const d = BalanceDrift(
        accountId: 1,
        accountName: 'Bank',
        storedBalance: 95000,
        initialBalance: 100000,
        sumOfDeltas: -5000,
        txCount: 1,
        backfilled: false,
      );
      expect(d.expectedBalance, 95000);
      expect(d.drift, 0);
      expect(d.hasDrift, isFalse);
    });

    test('hasDrift detects mismatch', () {
      const d = BalanceDrift(
        accountId: 1,
        accountName: 'Bank',
        storedBalance: 100000, // stored stayed at 100k
        initialBalance: 100000,
        sumOfDeltas: -5000,    // but a tx applied -5k delta
        txCount: 1,
        backfilled: false,
      );
      expect(d.expectedBalance, 95000);
      expect(d.drift, 5000); // stored is 5k higher than expected
      expect(d.hasDrift, isTrue);
    });

    test('drift can be negative (stored < expected)', () {
      const d = BalanceDrift(
        accountId: 2,
        accountName: 'Card',
        storedBalance: -2_000_000,
        initialBalance: 0,
        sumOfDeltas: -1_500_000,
        txCount: 3,
        backfilled: false,
      );
      expect(d.expectedBalance, -1_500_000);
      expect(d.drift, -500_000);
      expect(d.hasDrift, isTrue);
    });

    test('backfilled flag carries through', () {
      const d = BalanceDrift(
        accountId: 1,
        accountName: 'Legacy',
        storedBalance: 100000,
        initialBalance: 100000,
        sumOfDeltas: 0,
        txCount: 0,
        backfilled: true,
      );
      expect(d.backfilled, isTrue);
      expect(d.hasDrift, isFalse);
    });
  });

  group('BalanceReconcileResult', () {
    test('isClean when driftCount is 0', () {
      const r = BalanceReconcileResult(
        reports: [],
        driftCount: 0,
        backfilledCount: 0,
      );
      expect(r.isClean, isTrue);
    });

    test('not clean when at least one drift', () {
      const r = BalanceReconcileResult(
        reports: [],
        driftCount: 1,
        backfilledCount: 0,
      );
      expect(r.isClean, isFalse);
    });

    test('backfilled-only result is still clean', () {
      const r = BalanceReconcileResult(
        reports: [],
        driftCount: 0,
        backfilledCount: 3,
      );
      expect(r.isClean, isTrue);
    });
  });
}
