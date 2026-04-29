// Module-5 unit test — DashboardMetrics.compute pure factory.
// Plan SC: FR-08 — 7 metrics correct on any account/tx mix.

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/db/app_database.dart';
import 'package:money_tracker_app/features/accounts/domain/account.dart';
import 'package:money_tracker_app/features/dashboard/domain/dashboard_metrics.dart';

void main() {
  group('DashboardMetrics.compute', () {
    test('empty inputs yield empty metrics', () {
      final m = DashboardMetrics.compute(
        accounts: const [],
        currentMonthIncome: 0,
        currentMonthExpense: 0,
      );
      expect(m, DashboardMetrics.empty);
    });

    test('aggregates by account type', () {
      final accounts = [
        _account(id: 1, type: AccountType.cash, balance: 4_200_000),
        _account(id: 2, type: AccountType.investment, balance: 32_800_000),
        _account(id: 3, type: AccountType.savings, balance: 8_500_000),
        _account(id: 4, type: AccountType.creditCard, balance: -1_352_500),
        _account(id: 5, type: AccountType.realEstate, balance: 200_000_000),
        _account(id: 6, type: AccountType.loan, balance: -150_000_000),
      ];
      final m = DashboardMetrics.compute(
        accounts: accounts,
        currentMonthIncome: 3_200_000,
        currentMonthExpense: 1_847_500,
      );

      expect(m.netWorth, 94_147_500); // sum of all balances
      expect(m.cashAssets, 4_200_000);
      expect(m.investmentAssets, 41_300_000); // investment + savings
      expect(m.creditCardBalance, -1_352_500);
      expect(m.availableCash, 2_847_500); // cash + card (negative)
      expect(m.currentMonthIncome, 3_200_000);
      expect(m.currentMonthExpense, 1_847_500);
      expect(m.currentMonthNet, 1_352_500);
    });

    test('availableCash goes negative when card debt exceeds cash', () {
      final m = DashboardMetrics.compute(
        accounts: [
          _account(id: 1, type: AccountType.cash, balance: 100_000),
          _account(id: 2, type: AccountType.creditCard, balance: -250_000),
        ],
        currentMonthIncome: 0,
        currentMonthExpense: 0,
      );
      expect(m.availableCash, -150_000);
    });

    test('real_estate counts toward netWorth but not cash/investment', () {
      final m = DashboardMetrics.compute(
        accounts: [
          _account(id: 1, type: AccountType.realEstate, balance: 200_000_000),
        ],
        currentMonthIncome: 0,
        currentMonthExpense: 0,
      );
      expect(m.netWorth, 200_000_000);
      expect(m.cashAssets, 0);
      expect(m.investmentAssets, 0);
      expect(m.creditCardBalance, 0);
      expect(m.availableCash, 0);
    });

    test('loan reduces netWorth', () {
      final m = DashboardMetrics.compute(
        accounts: [
          _account(id: 1, type: AccountType.cash, balance: 10_000_000),
          _account(id: 2, type: AccountType.loan, balance: -50_000_000),
        ],
        currentMonthIncome: 0,
        currentMonthExpense: 0,
      );
      expect(m.netWorth, -40_000_000);
      expect(m.availableCash, 10_000_000); // loan does not affect available cash
    });

    test('value equality + hash', () {
      const a = DashboardMetrics(
        netWorth: 100,
        cashAssets: 50,
        investmentAssets: 30,
        creditCardBalance: -10,
        currentMonthIncome: 200,
        currentMonthExpense: 80,
      );
      const b = DashboardMetrics(
        netWorth: 100,
        cashAssets: 50,
        investmentAssets: 30,
        creditCardBalance: -10,
        currentMonthIncome: 200,
        currentMonthExpense: 80,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}

Account _account({
  required int id,
  required AccountType type,
  required int balance,
}) {
  final at = DateTime(2026, 1, 1);
  return Account(
    id: id,
    name: 'a$id',
    type: type,
    balance: balance,
    isActive: true,
    parentAccountId: null,
    note: null,
    sortOrder: id,
    createdAt: at,
    updatedAt: at,
  );
}
