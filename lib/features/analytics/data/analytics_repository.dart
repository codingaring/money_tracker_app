// Design Ref: §4.1 — AnalyticsRepository.
// 읽기 전용. categoryDonut(month) + fixedVariableSeries(months).
// Plan SC: SC-2 (카테고리 분석 매월 1회 사용).
// M5: +4 Report 쿼리 (monthlyTrend/monthlyCategorySpend/yearSummary/budgetVsActual) + DTOs.

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/category_segment.dart';
import '../domain/monthly_split_series.dart';
import 'budget_repository.dart';

class AnalyticsRepository {
  AnalyticsRepository(this._db);

  final AppDatabase _db;

  /// Aggregates expense amounts per **대분류 (parent rollup)** for [month].
  /// Plan SC: FR-51 — leaf의 parent_category_id를 따라 대분류로 합산.
  /// parent NULL이면 자기 자신이 대분류.
  ///
  /// Window: `[month-start, next-month-start)`.
  /// Sorted by [CategorySegment.totalAmount] desc.
  Future<List<CategorySegment>> categoryDonut({required DateTime month}) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final tx = _db.transactions;
    final cat = _db.categories;

    final rows = await (_db.select(tx).join([
      innerJoin(cat, cat.id.equalsExp(tx.categoryId)),
    ])..where(
              tx.deletedAt.isNull() &
                  tx.type.equalsValue(TxType.expense) &
                  tx.occurredAt.isBiggerOrEqualValue(start) &
                  tx.occurredAt.isSmallerThanValue(end),
            ))
        .get();

    // M3: parent rollup. parent_category_id가 있으면 그 부모를, 없으면 자기
    // 자신을 대분류로 사용. 부모 정보가 필요하므로 모든 카테고리를 한 번 더
    // 조회 (소형 데이터셋이라 비용 미미).
    final allCats = await _db.select(_db.categories).get();
    final byId = {for (final c in allCats) c.id: c};

    final byParent = <int, _Aggregator>{};
    for (final row in rows) {
      final t = row.readTable(tx);
      final c = row.readTable(cat);
      // leaf의 parent를 따라 대분류 결정. parent의 카테고리 정보로 라벨링.
      final parentId = c.parentCategoryId ?? c.id;
      final parent = byId[parentId] ?? c;
      byParent
          .putIfAbsent(
            parentId,
            () => _Aggregator(parent.id, parent.name, parent.isFixed),
          )
          .add(t.amount);
    }
    return byParent.values
        .map(
          (a) => CategorySegment(
            categoryId: a.id,
            categoryName: a.name,
            isFixed: a.isFixed,
            totalAmount: a.total,
          ),
        )
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  /// Plan SC: FR-39 — 월별 일자별 expense 합계.
  /// Returns `Map<midnight_date, sum>`. Days with 0 total are NOT included.
  /// Window: `[month-start, next-month-start)`.
  ///
  /// 인덱스 (occurred_at DESC, deleted_at) 활용 + 월별 ~300건 가정 → ≤ 200ms.
  Future<Map<DateTime, int>> dailyExpenseMap({required DateTime month}) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final tx = _db.transactions;

    final rows = await (_db.select(tx)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.type.equalsValue(TxType.expense) &
              t.occurredAt.isBiggerOrEqualValue(start) &
              t.occurredAt.isSmallerThanValue(end)))
        .get();

    final map = <DateTime, int>{};
    for (final row in rows) {
      final day = DateTime(
        row.occurredAt.year,
        row.occurredAt.month,
        row.occurredAt.day,
      );
      map[day] = (map[day] ?? 0) + row.amount;
    }
    return map;
  }

  /// Last [months] months of expense, split into fixed/variable.
  /// Includes the current month. Empty months → 0/0 entries (preserves
  /// continuous x-axis in the line chart).
  Future<List<MonthlySplitSeries>> fixedVariableSeries({
    required int months,
    DateTime? now,
  }) async {
    if (months <= 0) return const [];
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month - (months - 1));
    final end = DateTime(today.year, today.month + 1);
    final tx = _db.transactions;
    final cat = _db.categories;

    final rows = await (_db.select(tx).join([
      innerJoin(cat, cat.id.equalsExp(tx.categoryId)),
    ])..where(
              tx.deletedAt.isNull() &
                  tx.type.equalsValue(TxType.expense) &
                  tx.occurredAt.isBiggerOrEqualValue(start) &
                  tx.occurredAt.isSmallerThanValue(end),
            ))
        .get();

    // Pre-seed [months] buckets so empty months still appear on the chart.
    final buckets = <String, _MonthBucket>{};
    for (var i = 0; i < months; i++) {
      final m = DateTime(today.year, today.month - (months - 1 - i));
      final key = _ymKey(m);
      buckets[key] = _MonthBucket(key);
    }
    for (final row in rows) {
      final t = row.readTable(tx);
      final c = row.readTable(cat);
      final key = _ymKey(t.occurredAt);
      final bucket = buckets[key];
      if (bucket == null) continue;
      if (c.isFixed) {
        bucket.fixed += t.amount;
      } else {
        bucket.variable += t.amount;
      }
    }
    return buckets.values
        .map(
          (b) => MonthlySplitSeries(
            yearMonth: b.key,
            fixedAmount: b.fixed,
            variableAmount: b.variable,
          ),
        )
        .toList();
  }

  static String _ymKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  /// Budget vs actual spending for [month]. Only categories with budgets.
  /// Parent rollup: budget on 대분류 counts self + child category transactions.
  /// Sorted by ratio desc (초과율 높은 순).
  Future<List<BudgetStatus>> budgetOverlay({required DateTime month}) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);

    final budgetRows = await (_db.select(_db.budgets).join([
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.budgets.categoryId),
      ),
    ])).get();

    if (budgetRows.isEmpty) return [];

    // All categories for child rollup (one query).
    final allCats = await _db.select(_db.categories).get();

    // Map: budgetCatId → [self + direct children]
    final groups = <int, List<int>>{};
    for (final row in budgetRows) {
      final catId = row.readTable(_db.categories).id;
      groups[catId] = allCats
          .where((c) => c.id == catId || c.parentCategoryId == catId)
          .map((c) => c.id)
          .toList();
    }

    // Single transaction query covering all relevant categories.
    final allCatIds = groups.values.expand((ids) => ids).toSet().toList();
    final txRows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.type.equalsValue(TxType.expense) &
              t.categoryId.isIn(allCatIds) &
              t.occurredAt.isBiggerOrEqualValue(start) &
              t.occurredAt.isSmallerThanValue(end)))
        .get();

    // Aggregate each tx into its budget category.
    final spending = <int, int>{for (final id in groups.keys) id: 0};
    for (final tx in txRows) {
      if (tx.categoryId == null) continue;
      for (final entry in groups.entries) {
        if (entry.value.contains(tx.categoryId)) {
          spending[entry.key] = spending[entry.key]! + tx.amount;
          break;
        }
      }
    }

    return budgetRows.map((row) {
      final cat = row.readTable(_db.categories);
      final b = row.readTable(_db.budgets);
      return BudgetStatus(
        categoryId: cat.id,
        categoryName: cat.name,
        spent: spending[cat.id] ?? 0,
        limit: b.monthlyLimit,
      );
    }).toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));
  }

  // ── M5 Report 쿼리 ──────────────────────────────────────────────────────────

  /// Design Ref: §4.4 — 12개월 수입/지출 집계. net = income - expense.
  Future<List<MonthlyTrend>> monthlyTrend({required int year}) async {
    final start = DateTime(year);
    final end = DateTime(year + 1);

    final rows = await (_db.select(_db.transactions)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.occurredAt.isBiggerOrEqualValue(start) &
              t.occurredAt.isSmallerThanValue(end)))
        .get();

    final map = <int, (int, int)>{};
    for (final t in rows) {
      final m = t.occurredAt.month;
      final (inc, exp) = map[m] ?? (0, 0);
      if (t.type == TxType.income) {
        map[m] = (inc + t.amount, exp);
      } else if (t.type == TxType.expense) {
        map[m] = (inc, exp + t.amount);
      }
    }
    return List.generate(12, (i) {
      final m = i + 1;
      final (inc, exp) = map[m] ?? (0, 0);
      return MonthlyTrend(year: year, month: m, income: inc, expense: exp);
    });
  }

  /// Design Ref: §4.4 — 12개월 × 카테고리 지출 집계. 상위 parent rollup 기준.
  Future<List<MonthlyCategorySpend>> monthlyCategorySpend(
      {required int year}) async {
    final start = DateTime(year);
    final end = DateTime(year + 1);

    final rows = await (_db.select(_db.transactions).join([
      innerJoin(_db.categories,
          _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ])
          ..where(_db.transactions.deletedAt.isNull() &
              _db.transactions.type.equalsValue(TxType.expense) &
              _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
              _db.transactions.occurredAt.isSmallerThanValue(end)))
        .get();

    final allCats = await _db.select(_db.categories).get();
    final byId = {for (final c in allCats) c.id: c};

    final map = <(int, int), int>{};
    for (final row in rows) {
      final t = row.readTable(_db.transactions);
      final c = row.readTable(_db.categories);
      final parentId = c.parentCategoryId ?? c.id;
      final key = (t.occurredAt.month, parentId);
      map[key] = (map[key] ?? 0) + t.amount;
    }

    return map.entries.map((e) {
      final (month, catId) = e.key;
      final cat = byId[catId];
      return MonthlyCategorySpend(
        year: year,
        month: month,
        categoryId: catId,
        categoryName: cat?.name ?? '?',
        amount: e.value,
      );
    }).toList()
      ..sort((a, b) => a.month != b.month
          ? a.month.compareTo(b.month)
          : b.amount.compareTo(a.amount));
  }

  /// Design Ref: §4.4 — 연간 합계 + 전년 비교.
  Future<YearSummary> yearSummary({required int year}) async {
    Future<(int, int)> sumYear(int y) async {
      final start = DateTime(y);
      final end = DateTime(y + 1);
      final rows = await (_db.select(_db.transactions)
            ..where((t) =>
                t.deletedAt.isNull() &
                t.occurredAt.isBiggerOrEqualValue(start) &
                t.occurredAt.isSmallerThanValue(end)))
          .get();
      int inc = 0, exp = 0;
      for (final t in rows) {
        if (t.type == TxType.income) inc += t.amount;
        if (t.type == TxType.expense) exp += t.amount;
      }
      return (inc, exp);
    }

    final (inc, exp) = await sumYear(year);
    final (pInc, pExp) = await sumYear(year - 1);
    return YearSummary(
      year: year,
      totalIncome: inc,
      totalExpense: exp,
      prevYearIncome: pInc > 0 ? pInc : null,
      prevYearExpense: pExp > 0 ? pExp : null,
    );
  }

  /// Design Ref: §4.4 — 예산 설정 카테고리별 연간 평균 지출 vs 예산.
  Future<List<BudgetVsActual>> budgetVsActual({required int year}) async {
    final budgets = await (_db.select(_db.budgets).join([
      innerJoin(_db.categories,
          _db.categories.id.equalsExp(_db.budgets.categoryId)),
    ])).get();

    if (budgets.isEmpty) return [];

    final start = DateTime(year);
    final end = DateTime(year + 1);

    final result = <BudgetVsActual>[];
    for (final row in budgets) {
      final cat = row.readTable(_db.categories);
      final b = row.readTable(_db.budgets);
      final txRows = await (_db.select(_db.transactions)
            ..where((t) =>
                t.deletedAt.isNull() &
                t.type.equalsValue(TxType.expense) &
                t.categoryId.equals(cat.id) &
                t.occurredAt.isBiggerOrEqualValue(start) &
                t.occurredAt.isSmallerThanValue(end)))
          .get();
      final totalSpent = txRows.fold(0, (s, t) => s + t.amount);
      final monthsWithData =
          txRows.map((t) => t.occurredAt.month).toSet().length;
      result.add(BudgetVsActual(
        categoryId: cat.id,
        categoryName: cat.name,
        monthlyBudget: b.monthlyLimit,
        totalSpent: totalSpent,
        monthsWithData: monthsWithData,
      ));
    }
    result.sort((a, b) => b.avgRatio.compareTo(a.avgRatio));
    return result;
  }
}

class _Aggregator {
  _Aggregator(this.id, this.name, this.isFixed);
  final int id;
  final String name;
  final bool isFixed;
  int total = 0;
  void add(int amount) => total += amount;
}

class _MonthBucket {
  _MonthBucket(this.key);
  final String key;
  int fixed = 0;
  int variable = 0;
}

// ── M5 Report DTOs ────────────────────────────────────────────────────────────
// Design Ref: §3.3 — Option A 인라인 클래스.

class MonthlyTrend {
  const MonthlyTrend({
    required this.year,
    required this.month,
    required this.income,
    required this.expense,
  });
  final int year;
  final int month;
  final int income;
  final int expense;
  int get net => income - expense;
}

class MonthlyCategorySpend {
  const MonthlyCategorySpend({
    required this.year,
    required this.month,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
  });
  final int year;
  final int month;
  final int categoryId;
  final String categoryName;
  final int amount;
}

class YearSummary {
  const YearSummary({
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    this.prevYearIncome,
    this.prevYearExpense,
  });
  final int year;
  final int totalIncome;
  final int totalExpense;
  final int? prevYearIncome;
  final int? prevYearExpense;

  int get netIncome => totalIncome - totalExpense;
  double get savingsRate =>
      totalIncome > 0 ? netIncome / totalIncome : 0.0;
  int? get incomeGrowth => prevYearIncome != null && prevYearIncome! > 0
      ? totalIncome - prevYearIncome!
      : null;
  int? get expenseGrowth => prevYearExpense != null && prevYearExpense! > 0
      ? totalExpense - prevYearExpense!
      : null;
}

class BudgetVsActual {
  const BudgetVsActual({
    required this.categoryId,
    required this.categoryName,
    required this.monthlyBudget,
    required this.totalSpent,
    required this.monthsWithData,
  });
  final int categoryId;
  final String categoryName;
  final int monthlyBudget;
  final int totalSpent;
  final int monthsWithData;

  int get avgMonthlySpent =>
      monthsWithData > 0 ? totalSpent ~/ monthsWithData : 0;
  double get avgRatio =>
      monthlyBudget > 0 ? avgMonthlySpent / monthlyBudget : 0.0;
  bool get isAvgOver => avgMonthlySpent > monthlyBudget;
}
