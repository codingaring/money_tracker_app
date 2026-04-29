// Design Ref: §3.1 accounts.type — 6 enum values stored as text via textEnum.
// Design Ref: detail.md Accounts table — all assets and liabilities unified.

enum AccountType {
  /// 입출금 통장, 현금. 가용 현금 계산의 기반.
  cash,

  /// 주식 계좌, ISA. valuation 거래로 평가금 갱신.
  investment,

  /// 적금, 예금.
  savings,

  /// 전세 보증금 등.
  realEstate,

  /// 신용카드 (잔액은 부채로 음수 누적).
  creditCard,

  /// 전세 대출 등 (잔액은 음수).
  loan,
}

extension AccountTypeBucket on AccountType {
  /// Plan §1.3 가용 현금 / 대시보드 §4.5 분류 기반.
  bool get isCashLike => this == AccountType.cash;
  bool get isInvestmentLike =>
      this == AccountType.investment || this == AccountType.savings;
  bool get isLiability =>
      this == AccountType.creditCard || this == AccountType.loan;
}
