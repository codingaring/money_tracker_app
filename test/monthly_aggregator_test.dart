// Module-4 unit test — MonthlyAggregator pure function.
// Plan SC: monthly_summary push (FR-12).

import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/db/app_database.dart';
import 'package:money_tracker_app/features/accounts/domain/account.dart';
import 'package:money_tracker_app/features/sync/service/monthly_aggregator.dart';
import 'package:money_tracker_app/features/transactions/domain/transaction.dart';

void main() {
  // Pin "now" so the rolling window is deterministic.
  final now = DateTime(2026, 4, 15, 12, 0); // April 2026

  group('MonthlyAggregator.compute', () {
    test('months=0 returns empty', () {
      final r = MonthlyAggregator.compute(
        transactions: const [],
        accounts: const [],
        months: 0,
        now: now,
      );
      expect(r, isEmpty);
    });

    test('empty inputs yield N months of zeros (current netWorth carries)', () {
      final r = MonthlyAggregator.compute(
        transactions: const [],
        accounts: const [],
        months: 3,
        now: now,
      );
      expect(r.length, 3);
      expect(r.map((m) => m.yearMonth), ['2026-02', '2026-03', '2026-04']);
      for (final m in r) {
        expect(m.income, 0);
        expect(m.expense, 0);
        expect(m.net, 0);
        expect(m.netWorthEnd, 0);
      }
    });

    test('single-month income + expense aggregates correctly', () {
      final account = _account(id: 1, name: 'Bank', type: AccountType.cash, balance: 2_500_000);
      final transactions = [
        // Income: salary +3,200,000
        _tx(
          id: 1,
          localId: 'i1',
          type: TxType.income,
          amount: 3_200_000,
          toAccountId: 1,
          toDelta: 3_200_000,
          occurredAt: DateTime(2026, 4, 1),
        ),
        // Expense: lunch 12,000
        _tx(
          id: 2,
          localId: 'e1',
          type: TxType.expense,
          amount: 12_000,
          fromAccountId: 1,
          fromDelta: -12_000,
          occurredAt: DateTime(2026, 4, 5),
        ),
        // Expense: 688,000
        _tx(
          id: 3,
          localId: 'e2',
          type: TxType.expense,
          amount: 688_000,
          fromAccountId: 1,
          fromDelta: -688_000,
          occurredAt: DateTime(2026, 4, 10),
        ),
      ];

      final r = MonthlyAggregator.compute(
        transactions: transactions,
        accounts: [account],
        months: 1,
        now: now,
      );
      expect(r.length, 1);
      final m = r.single;
      expect(m.yearMonth, '2026-04');
      expect(m.income, 3_200_000);
      expect(m.expense, 700_000);
      expect(m.net, 2_500_000);
      expect(m.netWorthEnd, 2_500_000); // matches current accounts sum
    });

    test('netWorthEnd walks backward across months using stored deltas', () {
      // April: +3,200,000 income, -200,000 expense → net +3,000,000
      // March: -500,000 expense → net -500,000
      // Now (mid-April): netWorth = 4,500,000
      // Expected:
      //   netWorthEnd[April] = 4,500,000 (current)
      //   netWorthEnd[March] = 4,500,000 - (3,200,000 - 200,000) = 1,500,000
      //   netWorthEnd[Feb]   = 1,500,000 - (-500,000) = 2,000,000
      //                      (no Feb tx, monthDelta=0 → carry-over)
      //   wait — Feb has no tx, so its netWorthEnd = March's start = March end - March delta
      // Re-check: walking backward Apr → Mar → Feb
      //   Start: running = 4,500,000 → Apr.netWorthEnd = 4,500,000; subtract Apr delta
      //          (income +3,200,000, expense -200,000, total delta = +3,200,000 + (-200,000) = +3,000,000)
      //          running -= 3,000,000 → 1,500,000
      //   Mar.netWorthEnd = 1,500,000; subtract Mar delta (expense -500,000 → delta = -500,000)
      //          running -= -500,000 → running becomes 2,000,000
      //   Feb.netWorthEnd = 2,000,000; subtract 0 (no tx) → running stays 2,000,000
      final account = _account(
        id: 1,
        name: 'Bank',
        type: AccountType.cash,
        balance: 4_500_000,
      );
      final transactions = [
        _tx(
          id: 1,
          localId: 'a',
          type: TxType.income,
          amount: 3_200_000,
          toAccountId: 1,
          toDelta: 3_200_000,
          occurredAt: DateTime(2026, 4, 1),
        ),
        _tx(
          id: 2,
          localId: 'b',
          type: TxType.expense,
          amount: 200_000,
          fromAccountId: 1,
          fromDelta: -200_000,
          occurredAt: DateTime(2026, 4, 10),
        ),
        _tx(
          id: 3,
          localId: 'c',
          type: TxType.expense,
          amount: 500_000,
          fromAccountId: 1,
          fromDelta: -500_000,
          occurredAt: DateTime(2026, 3, 15),
        ),
      ];

      final r = MonthlyAggregator.compute(
        transactions: transactions,
        accounts: [account],
        months: 3,
        now: now,
      );
      expect(r.length, 3);
      expect(r.map((m) => m.yearMonth), ['2026-02', '2026-03', '2026-04']);

      expect(r[2].netWorthEnd, 4_500_000); // April
      expect(r[1].netWorthEnd, 1_500_000); // March
      expect(r[0].netWorthEnd, 2_000_000); // February
    });

    test('valuation uses to_delta only (no income/expense impact)', () {
      // Stock account valuation went from 1,000,000 → 1,200,000.
      // toDelta = +200,000.
      // No "income" or "expense" recorded — net should be 0.
      final account = _account(
        id: 5,
        name: 'Brokerage',
        type: AccountType.investment,
        balance: 1_200_000,
      );
      final transactions = [
        _tx(
          id: 1,
          localId: 'v1',
          type: TxType.valuation,
          amount: 1_200_000, // absolute new balance
          toAccountId: 5,
          toDelta: 200_000, // computed by DeltaCalculator
          occurredAt: DateTime(2026, 4, 30),
        ),
      ];
      final r = MonthlyAggregator.compute(
        transactions: transactions,
        accounts: [account],
        months: 1,
        now: now,
      );
      expect(r.single.income, 0);
      expect(r.single.expense, 0);
      expect(r.single.net, 0);
      expect(r.single.netWorthEnd, 1_200_000);
    });

    test('transfer is zero-sum (net delta = 0)', () {
      final cash = _account(id: 1, name: 'Bank', type: AccountType.cash, balance: 850_000);
      final card = _account(id: 2, name: 'Card', type: AccountType.creditCard, balance: 0);
      // 카드값 결제 150,000: bank -150k, card +150k → net 0 → netWorth unchanged.
      final transactions = [
        _tx(
          id: 1,
          localId: 't1',
          type: TxType.transfer,
          amount: 150_000,
          fromAccountId: 1,
          toAccountId: 2,
          fromDelta: -150_000,
          toDelta: 150_000,
          occurredAt: DateTime(2026, 4, 10),
        ),
      ];
      final r = MonthlyAggregator.compute(
        transactions: transactions,
        accounts: [cash, card],
        months: 1,
        now: now,
      );
      expect(r.single.income, 0);
      expect(r.single.expense, 0);
      expect(r.single.net, 0);
      expect(r.single.netWorthEnd, 850_000); // unchanged
    });

    test('soft-deleted transactions are excluded', () {
      final account = _account(id: 1, name: 'Bank', type: AccountType.cash, balance: 1_000_000);
      final transactions = [
        _tx(
          id: 1,
          localId: 'a',
          type: TxType.expense,
          amount: 50_000,
          fromAccountId: 1,
          fromDelta: -50_000,
          occurredAt: DateTime(2026, 4, 1),
          deletedAt: DateTime(2026, 4, 2), // soft-deleted
        ),
      ];
      final r = MonthlyAggregator.compute(
        transactions: transactions,
        accounts: [account],
        months: 1,
        now: now,
      );
      expect(r.single.expense, 0); // deleted tx ignored
    });

    test('year boundary: months=14 includes prior year', () {
      // Now is 2026-04. months=14 → from 2025-03 through 2026-04.
      final r = MonthlyAggregator.compute(
        transactions: const [],
        accounts: const [],
        months: 14,
        now: now,
      );
      expect(r.first.yearMonth, '2025-03');
      expect(r.last.yearMonth, '2026-04');
      expect(r.length, 14);
    });

    test('formatYearMonth pads single-digit months', () {
      expect(MonthlyAggregator.formatYearMonth(DateTime(2026, 3, 15)), '2026-03');
      expect(MonthlyAggregator.formatYearMonth(DateTime(2026, 12, 1)), '2026-12');
    });
  });

  group('MonthlySummary equality', () {
    test('value equality', () {
      const a = MonthlySummary(
          yearMonth: '2026-04', income: 100, expense: 30, netWorthEnd: 70);
      const b = MonthlySummary(
          yearMonth: '2026-04', income: 100, expense: 30, netWorthEnd: 70);
      expect(a, b);
    });

    test('net is derived', () {
      const m = MonthlySummary(
          yearMonth: '2026-04', income: 100, expense: 30, netWorthEnd: 70);
      expect(m.net, 70);
    });
  });
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Account _account({
  required int id,
  required String name,
  required AccountType type,
  required int balance,
  bool isActive = true,
  int? parentAccountId,
  String? note,
  int sortOrder = 0,
}) {
  final at = DateTime(2026, 1, 1);
  return Account(
    id: id,
    name: name,
    type: type,
    balance: balance,
    isActive: isActive,
    parentAccountId: parentAccountId,
    note: note,
    sortOrder: sortOrder,
    createdAt: at,
    updatedAt: at,
  );
}

TxRow _tx({
  required int id,
  required String localId,
  required TxType type,
  required int amount,
  required DateTime occurredAt,
  int? categoryId,
  int? fromAccountId,
  int? toAccountId,
  int? fromDelta,
  int? toDelta,
  String? memo,
  DateTime? deletedAt,
  DateTime? syncedAt,
}) {
  final at = DateTime(2026, 1, 1);
  return TxRow(
    id: id,
    localId: localId,
    type: type,
    amount: amount,
    categoryId: categoryId,
    fromAccountId: fromAccountId,
    toAccountId: toAccountId,
    fromDelta: fromDelta,
    toDelta: toDelta,
    memo: memo,
    occurredAt: occurredAt,
    createdAt: at,
    updatedAt: at,
    deletedAt: deletedAt,
    syncedAt: syncedAt,
  );
}
