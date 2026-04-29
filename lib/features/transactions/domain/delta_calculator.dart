// Design Ref: §4.3 DeltaCalculator — pure function, type → balance deltas.
// Plan SC: 잔액 무결성 (FR-04, FR-18).
//
// Stored on transactions.from_delta / to_delta to make undo on
// update/delete trivial (just invert the sign).

import 'transaction.dart';

class TxDeltas {
  const TxDeltas({this.fromDelta, this.toDelta});

  /// What was applied to from_account.balance. NULL means no change to from.
  final int? fromDelta;

  /// What was applied to to_account.balance. NULL means no change to to.
  final int? toDelta;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TxDeltas &&
          other.fromDelta == fromDelta &&
          other.toDelta == toDelta);

  @override
  int get hashCode => Object.hash(fromDelta, toDelta);

  @override
  String toString() => 'TxDeltas(from=$fromDelta, to=$toDelta)';
}

class DeltaCalculator {
  const DeltaCalculator._();

  /// Pure. For valuation, caller MUST supply [prevBalanceForValuation]
  /// (the to_account's balance at the moment delta is computed).
  static TxDeltas compute({
    required TxType type,
    required int amount,
    int? prevBalanceForValuation,
  }) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be > 0');
    }
    switch (type) {
      case TxType.expense:
        return TxDeltas(fromDelta: -amount);
      case TxType.income:
        return TxDeltas(toDelta: amount);
      case TxType.transfer:
        return TxDeltas(fromDelta: -amount, toDelta: amount);
      case TxType.valuation:
        if (prevBalanceForValuation == null) {
          throw ArgumentError.notNull('prevBalanceForValuation');
        }
        return TxDeltas(toDelta: amount - prevBalanceForValuation);
    }
  }

  /// Inverse of [compute] — used for undo on update/delete.
  static TxDeltas invert(TxDeltas d) => TxDeltas(
        fromDelta: d.fromDelta == null ? null : -d.fromDelta!,
        toDelta: d.toDelta == null ? null : -d.toDelta!,
      );
}
