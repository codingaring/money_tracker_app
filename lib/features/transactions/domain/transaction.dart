// Design Ref: §3.3 — 4-type Tx model.
// detail.md §13~88 spec.
//
// Pragmatic note: read-side type is Drift's generated `TxRow` (see tables.dart
// @DataClassName('TxRow')). NewTransaction is the input DTO.

enum TxType {
  /// 돈이 사라지는 것. from_account 필수, category(kind=expense) 필수.
  expense,

  /// 돈이 들어오는 것. to_account 필수, category(kind=income) 필수.
  income,

  /// 내 자산 간 이동 (순자산 불변). from + to 필수, from != to.
  transfer,

  /// 시세 변동 잔액 갱신 (주식 평가금 등). to 필수, amount = 절대 평가금.
  valuation,
}

class NewTransaction {
  const NewTransaction({
    required this.type,
    required this.amount,
    required this.occurredAt,
    this.fromAccountId,
    this.toAccountId,
    this.categoryId,
    this.memo,
  });

  final TxType type;

  /// Always positive (KRW). Sign is determined by type / direction at apply time.
  final int amount;

  final int? fromAccountId;
  final int? toAccountId;
  final int? categoryId;

  final String? memo;
  final DateTime occurredAt;

  /// Type-specific field invariants — see Design §3.3 type별 필드 사용 표.
  /// Repository runs this before any DB write. Returns null if valid,
  /// otherwise an error message describing the violation.
  String? validate() {
    if (amount <= 0) return 'amount must be > 0';
    switch (type) {
      case TxType.expense:
        if (fromAccountId == null) return 'expense requires fromAccountId';
        if (toAccountId != null) return 'expense must not have toAccountId';
        if (categoryId == null) return 'expense requires categoryId';
      case TxType.income:
        if (toAccountId == null) return 'income requires toAccountId';
        if (fromAccountId != null) return 'income must not have fromAccountId';
        if (categoryId == null) return 'income requires categoryId';
      case TxType.transfer:
        if (fromAccountId == null) return 'transfer requires fromAccountId';
        if (toAccountId == null) return 'transfer requires toAccountId';
        if (fromAccountId == toAccountId) {
          return 'transfer fromAccountId and toAccountId must differ';
        }
        if (categoryId != null) return 'transfer must not have categoryId';
      case TxType.valuation:
        if (toAccountId == null) return 'valuation requires toAccountId';
        if (fromAccountId != null) return 'valuation must not have fromAccountId';
        if (categoryId != null) return 'valuation must not have categoryId';
    }
    return null;
  }
}
