// Design Ref: §4.1 — AnalyticsRepository.
// 읽기 전용. categoryDonut(month) + fixedVariableSeries(months).
// Plan SC: SC-2 (카테고리 분석 매월 1회 사용).

import 'package:drift/drift.dart';

import '../../../core/db/app_database.dart';
import '../../transactions/domain/transaction.dart';
import '../domain/category_segment.dart';
import '../domain/monthly_split_series.dart';

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
