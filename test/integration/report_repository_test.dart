// Plan SC: FR-72~75 — Report 쿼리 통합 테스트 3건.
// monthlyTrend / yearSummary / budgetVsActual.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:money_tracker_app/core/db/app_database.dart';
import 'package:money_tracker_app/features/accounts/domain/account.dart';
import 'package:money_tracker_app/features/analytics/data/analytics_repository.dart';
import 'package:money_tracker_app/features/categories/domain/category.dart';
import 'package:money_tracker_app/features/transactions/domain/transaction.dart';

void main() {
  late AppDatabase db;
  late AnalyticsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = AnalyticsRepository(db);
  });

  tearDown(() async => db.close());

  // ── monthlyTrend ─────────────────────────────────────────────────────────────

  test('monthlyTrend — 1월 수입+지출, 2월 지출 → net 정확', () async {
    final catId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: '식비', kind: CategoryKind.expense),
        );
    final accId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(name: '체크카드', type: AccountType.cash),
        );

    // 1월 수입 500,000
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      localId: 'r1',
      type: TxType.income,
      amount: 500000,
      toAccountId: Value(accId),
      occurredAt: DateTime(2026, 1, 10),
    ));
    // 1월 지출 200,000
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      localId: 'r2',
      type: TxType.expense,
      amount: 200000,
      categoryId: Value(catId),
      fromAccountId: Value(accId),
      occurredAt: DateTime(2026, 1, 20),
    ));
    // 2월 지출 150,000
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      localId: 'r3',
      type: TxType.expense,
      amount: 150000,
      categoryId: Value(catId),
      fromAccountId: Value(accId),
      occurredAt: DateTime(2026, 2, 5),
    ));

    final result = await repo.monthlyTrend(year: 2026);

    expect(result, hasLength(12));
    final jan = result.firstWhere((r) => r.month == 1);
    expect(jan.income, 500000);
    expect(jan.expense, 200000);
    expect(jan.net, 300000);

    final feb = result.firstWhere((r) => r.month == 2);
    expect(feb.income, 0);
    expect(feb.expense, 150000);

    // 빈 달은 0
    final mar = result.firstWhere((r) => r.month == 3);
    expect(mar.income, 0);
    expect(mar.expense, 0);
  });

  // ── yearSummary ───────────────────────────────────────────────────────────────

  test('yearSummary — 전년 데이터 없으면 prevYearIncome = null', () async {
    final accId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(name: '체크카드', type: AccountType.cash),
        );

    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      localId: 's1',
      type: TxType.income,
      amount: 1000000,
      toAccountId: Value(accId),
      occurredAt: DateTime(2026, 3, 1),
    ));

    final result = await repo.yearSummary(year: 2026);
    expect(result.year, 2026);
    expect(result.totalIncome, 1000000);
    expect(result.totalExpense, 0);
    expect(result.prevYearIncome, isNull); // 2025년 데이터 없음
    expect(result.savingsRate, 1.0);
  });

  // ── budgetVsActual ────────────────────────────────────────────────────────────

  test('budgetVsActual — budget 1건 + expense → avgRatio 정확', () async {
    final catId = await db.into(db.categories).insert(
          CategoriesCompanion.insert(name: '식비', kind: CategoryKind.expense),
        );
    final accId = await db.into(db.accounts).insert(
          AccountsCompanion.insert(name: '체크카드', type: AccountType.cash),
        );

    // 월 예산 300,000
    await db.into(db.budgets).insert(
          BudgetsCompanion.insert(
            categoryId: catId,
            monthlyLimit: 300000,
          ),
        );

    // 1월 지출 240,000 (avgRatio = 0.8 = 80%)
    await db.into(db.transactions).insert(TransactionsCompanion.insert(
      localId: 'b1',
      type: TxType.expense,
      amount: 240000,
      categoryId: Value(catId),
      fromAccountId: Value(accId),
      occurredAt: DateTime(2026, 1, 15),
    ));

    final result = await repo.budgetVsActual(year: 2026);

    expect(result, hasLength(1));
    final bva = result.first;
    expect(bva.categoryName, '식비');
    expect(bva.monthlyBudget, 300000);
    expect(bva.totalSpent, 240000);
    expect(bva.monthsWithData, 1);
    expect(bva.avgMonthlySpent, 240000);
    expect(bva.avgRatio, closeTo(0.8, 0.001));
    expect(bva.isAvgOver, isFalse);
  });
}
