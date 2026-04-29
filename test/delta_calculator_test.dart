// Module-2 unit test — DeltaCalculator (pure function, 100% target coverage).
// Covers Plan SC FR-04 (잔액 자동 갱신) at the unit level.

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/features/transactions/domain/delta_calculator.dart';
import 'package:money_tracker_app/features/transactions/domain/transaction.dart';

void main() {
  group('DeltaCalculator.compute', () {
    test('expense: from -amount, to null', () {
      final d = DeltaCalculator.compute(type: TxType.expense, amount: 12000);
      expect(d, const TxDeltas(fromDelta: -12000));
    });

    test('income: from null, to +amount', () {
      final d = DeltaCalculator.compute(type: TxType.income, amount: 3200000);
      expect(d, const TxDeltas(toDelta: 3200000));
    });

    test('transfer: from -amount, to +amount', () {
      final d = DeltaCalculator.compute(type: TxType.transfer, amount: 150000);
      expect(d, const TxDeltas(fromDelta: -150000, toDelta: 150000));
    });

    test('valuation upward: to = new - prev (positive)', () {
      final d = DeltaCalculator.compute(
        type: TxType.valuation,
        amount: 1200000,
        prevBalanceForValuation: 1000000,
      );
      expect(d, const TxDeltas(toDelta: 200000));
    });

    test('valuation downward: to = new - prev (negative)', () {
      final d = DeltaCalculator.compute(
        type: TxType.valuation,
        amount: 800000,
        prevBalanceForValuation: 1000000,
      );
      expect(d, const TxDeltas(toDelta: -200000));
    });

    test('valuation no-op: to = 0 when new equals prev', () {
      final d = DeltaCalculator.compute(
        type: TxType.valuation,
        amount: 1000000,
        prevBalanceForValuation: 1000000,
      );
      expect(d, const TxDeltas(toDelta: 0));
    });

    test('valuation without prevBalance throws', () {
      expect(
        () => DeltaCalculator.compute(type: TxType.valuation, amount: 1000),
        throwsArgumentError,
      );
    });

    test('amount <= 0 throws (defensive)', () {
      expect(
        () => DeltaCalculator.compute(type: TxType.expense, amount: 0),
        throwsArgumentError,
      );
      expect(
        () => DeltaCalculator.compute(type: TxType.income, amount: -100),
        throwsArgumentError,
      );
    });
  });

  group('DeltaCalculator.invert', () {
    test('inverts both signs when both present (transfer)', () {
      const d = TxDeltas(fromDelta: -150000, toDelta: 150000);
      expect(
        DeltaCalculator.invert(d),
        const TxDeltas(fromDelta: 150000, toDelta: -150000),
      );
    });

    test('preserves nulls (expense)', () {
      const d = TxDeltas(fromDelta: -12000);
      expect(
        DeltaCalculator.invert(d),
        const TxDeltas(fromDelta: 12000),
      );
    });

    test('inverts negative valuation delta', () {
      const d = TxDeltas(toDelta: -200000);
      expect(DeltaCalculator.invert(d), const TxDeltas(toDelta: 200000));
    });

    test('zero delta inverts to zero', () {
      const d = TxDeltas(toDelta: 0);
      expect(DeltaCalculator.invert(d), const TxDeltas(toDelta: 0));
    });

    test('compose: invert(invert(x)) == x', () {
      const d = TxDeltas(fromDelta: -50000, toDelta: 50000);
      expect(DeltaCalculator.invert(DeltaCalculator.invert(d)), d);
    });
  });

  group('TxDeltas equality', () {
    test('same values equal', () {
      expect(
        const TxDeltas(fromDelta: -100, toDelta: 100),
        const TxDeltas(fromDelta: -100, toDelta: 100),
      );
    });

    test('different values not equal', () {
      expect(
        const TxDeltas(fromDelta: -100),
        isNot(const TxDeltas(toDelta: -100)),
      );
    });
  });
}
