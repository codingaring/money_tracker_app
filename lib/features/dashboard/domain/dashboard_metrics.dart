// Design Ref: §4.5, §5.1 — 7 metrics shown on HomeScreen.
// Plan SC: FR-08 — 순자산/현금성/투자/카드미결제/가용현금/월지출/월수입.
//
// **Pure value object + factory**: no DB / time access. Repository wires it up.

import '../../accounts/domain/account.dart';
import '../../../core/db/app_database.dart';

class DashboardMetrics {
  const DashboardMetrics({
    required this.netWorth,
    required this.cashAssets,
    required this.investmentAssets,
    required this.creditCardBalance,
    required this.currentMonthIncome,
    required this.currentMonthExpense,
  });

  /// Pure aggregation — testable without a DB.
  /// [accounts] should be the active set (`is_active = true`).
  factory DashboardMetrics.compute({
    required List<Account> accounts,
    required int currentMonthIncome,
    required int currentMonthExpense,
  }) {
    var netWorth = 0;
    var cash = 0;
    var invest = 0;
    var card = 0;
    for (final a in accounts) {
      netWorth += a.balance;
      if (a.type.isCashLike) cash += a.balance;
      if (a.type.isInvestmentLike) invest += a.balance;
      if (a.type == AccountType.creditCard) card += a.balance;
    }
    return DashboardMetrics(
      netWorth: netWorth,
      cashAssets: cash,
      investmentAssets: invest,
      creditCardBalance: card,
      currentMonthIncome: currentMonthIncome,
      currentMonthExpense: currentMonthExpense,
    );
  }

  /// Sum of all active account balances. Liabilities (credit_card, loan) are
  /// stored negative so they subtract automatically.
  final int netWorth;

  /// Sum of `type=cash` balances.
  final int cashAssets;

  /// Sum of `type IN (investment, savings)` balances.
  final int investmentAssets;

  /// Sum of `type=credit_card` balances. Negative under normal usage.
  final int creditCardBalance;

  /// Income transactions in current calendar month.
  final int currentMonthIncome;

  /// Expense transactions in current calendar month.
  final int currentMonthExpense;

  /// Plan §1.3 핵심 지표: cashAssets + creditCardBalance (creditCardBalance is
  /// already negative). "내 통장에 있는 돈 - 다음 달 빠질 카드값".
  int get availableCash => cashAssets + creditCardBalance;

  int get currentMonthNet => currentMonthIncome - currentMonthExpense;

  static const empty = DashboardMetrics(
    netWorth: 0,
    cashAssets: 0,
    investmentAssets: 0,
    creditCardBalance: 0,
    currentMonthIncome: 0,
    currentMonthExpense: 0,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DashboardMetrics &&
          other.netWorth == netWorth &&
          other.cashAssets == cashAssets &&
          other.investmentAssets == investmentAssets &&
          other.creditCardBalance == creditCardBalance &&
          other.currentMonthIncome == currentMonthIncome &&
          other.currentMonthExpense == currentMonthExpense);

  @override
  int get hashCode => Object.hash(
        netWorth,
        cashAssets,
        investmentAssets,
        creditCardBalance,
        currentMonthIncome,
        currentMonthExpense,
      );

  @override
  String toString() => 'DashboardMetrics('
      'net=$netWorth, cash=$cashAssets, invest=$investmentAssets, '
      'card=$creditCardBalance, available=$availableCash, '
      'income=$currentMonthIncome, expense=$currentMonthExpense)';
}
