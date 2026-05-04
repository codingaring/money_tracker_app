---
template: design
version: 1.0
feature: budget-tracker-m5
cycle: M5
date: 2026-04-30
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.6.0"
level: Dynamic
architecture: Option A — analytics 폴더 확장 (ReportsScreen + 쿼리를 analytics/ 내부에 추가)
basePlan: docs/01-plan/features/budget-tracker-m5.plan.md
baseDesign: docs/archive/2026-04/budget-tracker-m4/budget-tracker-m4.design.md
---

# Budget Tracker — M5 Design Document

> **Architecture**: Option A — 신규 feature 디렉터리 없이 기존 `analytics/` 폴더에 파일 추가.
> ReportRepository 쿼리는 `analytics_repository.dart` 인라인 메서드로 추가.
> UI 위젯은 `analytics/ui/` 하위에 신규 파일로 추가.
>
> **M4 → M5 핵심 변경**: Schema v6(recurrence_type+day_of_week) + isDue 확장 + RecurringRuleFormSheet picker + categories 소분류 drag-reorder + 5번째 리포트 탭 + 연간 4종 시각화.

---

## Context Anchor (Plan Carry-Over)

| Key | Value |
|-----|-------|
| **WHY** | 단기 통제(M4) 이후 중장기 인사이트 확보 + 반복 거래 주기 다양화 → 앱 기능 완결 |
| **WHO** | 본인 1인 (M1~M4 사용자). 2~3개월 데이터 누적, 연간 추이 파악 니즈 발생 |
| **RISK** | (1) 리포트 쿼리 성능 (12개월 집계) (2) isDue weekly 주 경계 계산 (3) v5→v6 마이그레이션 (4) 5탭 네비게이션 레이아웃 |
| **SUCCESS** | 리포트 탭에서 연간 수입/지출 라인 + 월별 카테고리 바 확인 / 매주·매일 반복 등록 / FR-68 drag-reorder |
| **SCOPE** | FR-68 backlog + 반복 주기(weekly/daily, schema v6) + 리포트 탭(4종 시각화, analytics/ 확장) |

---

## 1. Overview

### 1.1 변경 요약 (M4 → M5)

```
M4 = 자동 + 통제 (반복거래 알림 + 예산 한도)
M5 = 인사이트 + 완결 (연간 리포트 + 반복 주기 다양화)
```

| 영역 | M4 | M5 추가 |
|------|----|---------|
| Schema | v5 (recurring_rules + budgets) | v6 + recurrence_type + day_of_week |
| 반복 거래 | 매월 N일만 | + 매주 N요일 / 매일 |
| 분석 | 달력 + 도너츠 + 라인 + 예산 오버레이 | + 5번째 탭(리포트) — 연간 4종 시각화 |
| 카테고리 | 대분류만 drag-reorder | + 소분류도 drag-reorder (FR-68) |
| 신규 파일 | — | analytics/ui/ ×5 + migrations/v5_to_v6.dart |

### 1.2 변경 없는 부분

| 영역 | 그대로 |
|------|--------|
| 회계 모델 | 4-type Tx + Accounts |
| Sheets 동기화 | one-way push |
| 상태관리 | Riverpod 2.x |
| 기존 기능 전체 | M1~M4 코드 수정 최소화 (isDue 확장, FormSheet picker, categories child reorder만) |

---

## 2. Architecture (Option A — analytics 폴더 확장)

### 2.1 파일 변경 맵

```
money_tracker_app/lib/
├── core/db/
│   ├── tables.dart                                        # ✏️ RecurringRules: +recurrenceType, +dayOfWeek
│   ├── app_database.dart                                  # ✏️ schemaVersion=6, v5→v6 호출
│   └── migrations/
│       └── v5_to_v6.dart                                  # 🆕 addColumn ×2
├── features/
│   ├── analytics/
│   │   ├── data/
│   │   │   └── analytics_repository.dart                  # ✏️ +4 DTOs + 4 report 쿼리 메서드
│   │   └── ui/
│   │       ├── reports_screen.dart                        # 🆕 5번째 탭 메인
│   │       ├── monthly_trend_chart.dart                   # 🆕 라인 차트 위젯
│   │       ├── monthly_category_bar_chart.dart            # 🆕 바 차트 위젯
│   │       ├── year_summary_card.dart                     # 🆕 연간 요약 카드
│   │       └── budget_comparison_section.dart             # 🆕 예산 vs 실제
│   ├── categories/ui/
│   │   └── categories_screen.dart                         # ✏️ FR-68: _TopLevelTile children → ReorderableListView
│   └── dashboard/
│       ├── data/
│       │   └── recurring_rule_repository.dart             # ✏️ isDue switch 분기 (weekly/daily)
│       └── ui/
│           └── recurring_rule_form_sheet.dart             # ✏️ recurrence_type picker + day_of_week picker
├── app/
│   ├── providers.dart                                     # ✏️ +report providers (4종)
│   └── router.dart                                        # ✏️ 5번째 탭 /reports + _BottomNav +1
```

**신규 파일**: 6개 / **수정 파일**: 8개 / 예상 LOC: ~900

### 2.2 의존성 그래프 (신규)

```
ReportsScreen
  └── ref.watch(yearSummaryProvider(year))
        AnalyticsRepository.yearSummary(year)
          └── AppDatabase.transactions
  └── ref.watch(monthlyTrendProvider(year))
        AnalyticsRepository.monthlyTrend(year)
  └── ref.watch(monthlyCategorySpendProvider(year))
        AnalyticsRepository.monthlyCategorySpend(year)
          └── AppDatabase.transactions + categories
  └── ref.watch(budgetVsActualProvider(year))
        AnalyticsRepository.budgetVsActual(year)
          └── AppDatabase.transactions + budgets + categories
```

---

## 3. Data Model

### 3.1 Schema v6 Delta — recurring_rules 컬럼 추가

```dart
// core/db/tables.dart — RecurringRules 클래스 수정
// Design Ref: §3.1 — v6 delta. 매월 외 weekly/daily 지원.

// 기존 컬럼 유지 (id, templateId, dayOfMonth, isActive, lastConfirmedAt, createdAt, updatedAt)

/// 'monthly' | 'weekly' | 'daily'. 기존 행 default = 'monthly'.
TextColumn get recurrenceType =>
    text().withDefault(const Constant('monthly'))();

/// Dart DateTime.weekday: 1=Mon ~ 7=Sun.
/// weekly 시만 사용. monthly/daily는 null.
IntColumn get dayOfWeek => integer().nullable()();
```

### 3.2 마이그레이션 v5 → v6

```dart
// core/db/migrations/v5_to_v6.dart
// Design Ref: §3.2 — v5→v6. addColumn ×2. 기존 recurring_rules 데이터 보존.

class V5ToV6 {
  const V5ToV6._();
  static Future<void> apply(Migrator m, AppDatabase db) async {
    await m.addColumn(db.recurringRules, db.recurringRules.recurrenceType);
    await m.addColumn(db.recurringRules, db.recurringRules.dayOfWeek);
  }
}
```

```dart
// app_database.dart 수정 부분
@override
int get schemaVersion => 6;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 3) await V2ToV3.apply(m, this);
    if (from < 4) await V3ToV4.apply(m, this);
    if (from < 5) await V4ToV5.apply(m, this);
    if (from < 6) await V5ToV6.apply(m, this);
  },
  beforeOpen: (_) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

### 3.3 Report DTOs (analytics_repository.dart 인라인)

```dart
// analytics/data/analytics_repository.dart 하단에 추가
// Design Ref: §3.3 — Report DTOs. Option A: 인라인 클래스.

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
  int? get incomeGrowth =>
      prevYearIncome != null && prevYearIncome! > 0
          ? totalIncome - prevYearIncome!
          : null;
  int? get expenseGrowth =>
      prevYearExpense != null && prevYearExpense! > 0
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
  final int monthsWithData; // 1~12

  int get avgMonthlySpent =>
      monthsWithData > 0 ? totalSpent ~/ monthsWithData : 0;
  double get avgRatio =>
      monthlyBudget > 0 ? avgMonthlySpent / monthlyBudget : 0.0;
  bool get isAvgOver => avgMonthlySpent > monthlyBudget;
}
```

---

## 4. Component Specifications

### 4.1 RecurringRule isDue 확장

```dart
// dashboard/data/recurring_rule_repository.dart — isDue 메서드 수정
// Design Ref: §4.1 — isDue switch 분기. Plan SC-5 (weekly/daily 지원).

bool isDue(DateTime today) {
  if (!isActive) return false;

  switch (recurrenceType) {
    case 'daily':
      // 오늘 이미 처리했으면 false.
      if (lastConfirmedAt == null) return true;
      final lc = lastConfirmedAt!;
      return !(lc.year == today.year &&
               lc.month == today.month &&
               lc.day == today.day);

    case 'weekly':
      // 이 요일이 아니면 false.
      if (dayOfWeek != today.weekday) return false; // 1=Mon~7=Sun
      if (lastConfirmedAt == null) return true;
      // 이번 주 월요일 기준 비교.
      final todayMon = today.subtract(Duration(days: today.weekday - 1));
      final todayMonDate = DateTime(todayMon.year, todayMon.month, todayMon.day);
      final lc = lastConfirmedAt!;
      final lcMon = lc.subtract(Duration(days: lc.weekday - 1));
      final lcMonDate = DateTime(lcMon.year, lcMon.month, lcMon.day);
      return todayMonDate.isAfter(lcMonDate);

    default: // 'monthly'
      if (dayOfMonth > today.day) return false;
      if (lastConfirmedAt == null) return true;
      final lc = lastConfirmedAt!;
      return lc.year < today.year ||
          (lc.year == today.year && lc.month < today.month);
  }
}
```

### 4.2 RecurringRuleFormSheet 수정

기존 FormSheet에 recurrence_type 선택 UI 추가:

```dart
// 추가 위젯:
// 1. recurrence_type DropdownButtonFormField (매월/매주/매일)
// 2. conditional widget:
//    - monthly → 기존 dayOfMonth DropdownButton<int> (1~28)
//    - weekly  → dayOfWeek DropdownButton<int> (1=월 ~ 7=일, '월'~'일' 라벨)
//    - daily   → 날짜 선택 없음 (숨김)

DropdownButtonFormField<String>(
  value: _recurrenceType,  // 'monthly' | 'weekly' | 'daily'
  items: const [
    DropdownMenuItem(value: 'monthly', child: Text('매월')),
    DropdownMenuItem(value: 'weekly',  child: Text('매주')),
    DropdownMenuItem(value: 'daily',   child: Text('매일')),
  ],
  onChanged: (v) => setState(() => _recurrenceType = v!),
),

// conditional
if (_recurrenceType == 'monthly')
  DropdownButtonFormField<int>(/* 기존 1~28 */),
if (_recurrenceType == 'weekly')
  DropdownButtonFormField<int>(
    items: List.generate(7, (i) => i + 1)
        .map((d) => DropdownMenuItem(
              value: d,
              child: Text(['월','화','수','목','금','토','일'][d-1]),
            ))
        .toList(),
  ),
// daily: 선택 없음
```

### 4.3 categories_screen.dart — FR-68 소분류 drag-reorder

```dart
// categories_screen.dart — _TopLevelTile children 수정
// Design Ref: §4.3 — FR-68. ExpansionTile.children → ReorderableListView.

// 현재 (bug):
children: parent.children.map((child) => _ChildTile(child)).toList()

// 수정 후:
children: [
  ReorderableListView(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    onReorder: (oldIdx, newIdx) {
      final ids = parent.children.map((c) => c.id).toList();
      if (newIdx > oldIdx) newIdx--;
      final moved = ids.removeAt(oldIdx);
      ids.insert(newIdx, moved);
      ref.read(categoryRepositoryProvider).reorder(ids);
    },
    children: parent.children
        .map((child) => _ChildTile(key: ValueKey(child.id), child: child))
        .toList(),
  ),
],
```

### 4.4 AnalyticsRepository Report 쿼리 메서드

```dart
// analytics/data/analytics_repository.dart 추가 메서드
// Design Ref: §4.4 — Report 쿼리 4종.

/// 12개월 수입/지출 집계. net = income - expense.
Future<List<MonthlyTrend>> monthlyTrend({required int year}) async {
  final start = DateTime(year);
  final end = DateTime(year + 1);

  final rows = await (_db.select(_db.transactions)
        ..where((t) =>
            t.deletedAt.isNull() &
            t.occurredAt.isBiggerOrEqualValue(start) &
            t.occurredAt.isSmallerThanValue(end)))
      .get();

  // month → {income, expense}
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

/// 12개월 × 카테고리 지출 집계. 상위 카테고리(parent rollup) 기준.
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

  // (month, parentId) → amount
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
      year: year, month: month,
      categoryId: catId,
      categoryName: cat?.name ?? '?',
      amount: e.value,
    );
  }).toList()
    ..sort((a, b) =>
        a.month != b.month ? a.month.compareTo(b.month) : b.amount.compareTo(a.amount));
}

/// 연간 합계 + 전년 비교.
Future<YearSummary> yearSummary({required int year}) async {
  Future<(int, int)> _sumYear(int y) async {
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

  final (inc, exp) = await _sumYear(year);
  final (pInc, pExp) = await _sumYear(year - 1);
  return YearSummary(
    year: year,
    totalIncome: inc,
    totalExpense: exp,
    prevYearIncome: pInc > 0 ? pInc : null,
    prevYearExpense: pExp > 0 ? pExp : null,
  );
}

/// 예산 설정 카테고리별 연간 평균 지출 vs 예산.
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
```

---

## 5. UI Specifications

### 5.1 ReportsScreen 전체 레이아웃

```
┌──────────────────────────────────────┐
│  리포트                               │  ← AppBar (simple, no actions)
├──────────────────────────────────────┤
│   < 2025           2026           >  │  ← 연도 선택 Row
│         (미래 연도 > 비활성)           │
├──────────────────────────────────────┤
│  ┌────────────────────────────────┐  │
│  │  총수입         총지출   저축률  │  │  ← YearSummaryCard
│  │  ₩ 36,000,000   ₩ 28,000,000  │  │
│  │  +12% ▲ vs 전년  +5% ▲  22%   │  │
│  └────────────────────────────────┘  │
├──────────────────────────────────────┤
│  월별 수입 / 지출 추이                 │  ← 섹션 제목
│  [MonthlyTrendChart — 라인 2선 + net] │
│  수입(green) / 지출(red) / 순이익(blue)│
│  1월  2월  3월  4월  5월 ...          │
├──────────────────────────────────────┤
│  월별 카테고리 지출                    │  ← 섹션 제목
│  [MonthlyCategoryBarChart]           │
│  [1월 2월 3월 4월 5월 ... (스크롤)]   │
├──────────────────────────────────────┤
│  예산 vs 실제 평균 (예산 없으면 숨김)   │  ← BudgetComparisonSection
│  식비  [████░░░░] 75% avg  미달       │
│  교통  [██████████] 105% avg  초과 ⚠️ │
└──────────────────────────────────────┘
```

연도 선택 로직:
- 초기값: `DateTime.now().year`
- `>` 버튼: `selectedYear < DateTime.now().year`인 경우만 활성
- `<` 버튼: 데이터가 있는 최초 연도까지 허용 (또는 최대 5년 전)

### 5.2 MonthlyTrendChart

```dart
// analytics/ui/monthly_trend_chart.dart
// Design Ref: §5.2 — 수입/지출/순이익 3선 라인 차트.
// fl_chart LineChart. 기존 FixedVariableLineChart 패턴 재사용.

class MonthlyTrendChart extends StatelessWidget {
  const MonthlyTrendChart({super.key, required this.data});
  final List<MonthlyTrend> data; // 12개월, month 1~12

  // 3개 LineChartBarData:
  // - 수입: colorScheme.primary (green-ish)
  // - 지출: colorScheme.error (red)
  // - 순이익: colorScheme.tertiary (blue)
  // X축: 1~12월 (1자리 숫자 또는 '1월' ... '12월')
  // Y축: 원화 포맷 (moneyFormat 사용)
  // 데이터 없으면 _EmptyLine(theme) 반환
}
```

### 5.3 MonthlyCategoryBarChart

```dart
// analytics/ui/monthly_category_bar_chart.dart
// Design Ref: §5.3 — 월별 카테고리 지출 GroupedBarChart.

class MonthlyCategoryBarChart extends StatelessWidget {
  const MonthlyCategoryBarChart({super.key, required this.data});
  final List<MonthlyCategorySpend> data;

  // 상위 5개 카테고리 (연간 합계 기준) + 나머지 '기타' 합산
  // 각 월마다 GroupedBarData (카테고리별 색상 고정)
  // 카테고리 색상: colorScheme.primary / secondary / tertiary / ... 순환
  // 빈 달 (0원): 바 없음
  // 가로 스크롤 가능 (월 수가 많을 경우)
}
```

### 5.4 YearSummaryCard

```dart
// analytics/ui/year_summary_card.dart
// Design Ref: §5.4 — 연간 요약 카드.

class YearSummaryCard extends StatelessWidget {
  const YearSummaryCard({super.key, required this.summary});
  final YearSummary summary;

  // Card with 3 columns: 총수입 / 총지출 / 저축률
  // 각 컬럼: 값 + 전년 대비 delta (prevYear != null인 경우)
  // delta: +₩X (▲, green) / -₩X (▼, red)
  // 전년 데이터 없으면 delta 숨김
}
```

### 5.5 BudgetComparisonSection

```dart
// analytics/ui/budget_comparison_section.dart
// Design Ref: §5.5 — 예산 vs 실제 연간 평균.

class BudgetComparisonSection extends StatelessWidget {
  const BudgetComparisonSection({super.key, required this.data});
  final List<BudgetVsActual> data;

  // data.isEmpty → 섹션 전체 숨김 (SizedBox.shrink())
  // 각 항목: 카테고리명 + LinearProgressIndicator(value: avgRatio.clamp(0,1))
  //          + avgRatio% text + isAvgOver ? ⚠️ : ''
  // isAvgOver: 바 색상 colorScheme.error
}
```

---

## 6. State Management (M5 신규 Providers)

```dart
// app/providers.dart 추가
// Design Ref: §6 — Report providers.

// 연도별 파라미터: int year

final monthlyTrendProvider =
    FutureProvider.family<List<MonthlyTrend>, int>((ref, year) =>
        ref.watch(analyticsRepositoryProvider).monthlyTrend(year: year));

final monthlyCategorySpendProvider =
    FutureProvider.family<List<MonthlyCategorySpend>, int>((ref, year) =>
        ref.watch(analyticsRepositoryProvider).monthlyCategorySpend(year: year));

final yearSummaryProvider =
    FutureProvider.family<YearSummary, int>((ref, year) =>
        ref.watch(analyticsRepositoryProvider).yearSummary(year: year));

final budgetVsActualProvider =
    FutureProvider.family<List<BudgetVsActual>, int>((ref, year) =>
        ref.watch(analyticsRepositoryProvider).budgetVsActual(year: year));
```

ReportsScreen 내부 상태: `selectedYear` — `StatefulHookConsumerWidget` 또는 `StateProvider<int>` 로컬.

---

## 7. Test Plan

### 7.1 Unit Tests (M5 신규)

**RecurringRule.isDue 확장 — weekly/daily (4건)**

```dart
// test/recurring_rule_test.dart 추가 (기존 5건 + 4건 = 9건)
// 6. recurrenceType='weekly', dayOfWeek=오늘.weekday, lastConfirmedAt=null → true
// 7. recurrenceType='weekly', dayOfWeek=오늘.weekday, lastConfirmedAt=이번주 처리됨 → false
// 8. recurrenceType='daily', lastConfirmedAt=null → true
// 9. recurrenceType='daily', lastConfirmedAt=오늘 → false
```

### 7.2 Integration Tests (M5 신규)

**ReportRepository (3건)**

```dart
// test/integration/report_repository_test.dart
// 1. monthlyTrend — 3건 거래 insert (1월 수입, 1월 지출, 2월 지출) → 1월 net 확인
// 2. yearSummary — 연간 합계 + 전년 없으면 prevYearIncome = null
// 3. budgetVsActual — budget 1건 + expense insert → avgRatio 확인
```

**Migration Test 추가 (1건)**

```dart
// test/integration/migration_test.dart 추가
// v5→v6: DROP recurrenceType+dayOfWeek → V5ToV6.apply → 컬럼 복원 + 기존 데이터 보존
//        recurrenceType default 'monthly' 확인
```

### 7.3 Manual Verification (M5 DoD)

- [ ] 반복 거래 "매주 월요일" 등록 → isDue(월요일) = true 확인
- [ ] 반복 거래 "매일" 등록 → 홈 배지 표시 → 확인 → 다음날까지 배지 없음
- [ ] 설정 → 카테고리 → 소분류 드래그 → 순서 저장 확인
- [ ] 리포트 탭 → 연도 전환 → 차트 데이터 갱신
- [ ] 리포트 탭 → 예산 미설정 시 BudgetComparisonSection 숨김
- [ ] flutter analyze 0 issues

---

## 8. Routing (추가분)

```dart
// app/router.dart — 5번째 탭 추가
// imports: reports_screen.dart

// StatefulShellRoute.branches에 추가:
StatefulShellBranch(routes: [
  GoRoute(
    path: '/reports',
    builder: (_, _) => const ReportsScreen(),
  ),
]),

// _BottomNav._items에 추가:
_NavItemSpec(
  label: '리포트',
  icon: Icons.bar_chart_outlined,
  selectedIcon: Icons.bar_chart_rounded,
  index: 4,
),
```

현재 탭 순서: 홈(0) / 내역(1) / 분석(2) / 계좌(3) → M5: 계좌를 4번째로 유지하고 리포트를 3번째에 넣거나, 리포트를 5번째 추가.

**결정**: 기존 순서 유지 + 리포트를 마지막(4번)에 추가.
`홈(0) | 내역(1) | 분석(2) | 계좌(3) | 리포트(4)`

---

## 9. Performance & Security

| 영역 | 목표 | 전략 |
|------|------|------|
| monthlyTrend 쿼리 | ≤ 300ms | 12개월 전체 row 1회 fetch + Dart 집계. 데이터 수백 건 가정. |
| monthlyCategorySpend | ≤ 300ms | JOIN + Dart 집계. N+1 없음. |
| yearSummary | ≤ 400ms | 2년치 데이터 2회 쿼리. |
| budgetVsActual | ≤ 500ms | 카테고리당 1 쿼리. 예산 설정 카테고리 5~10건 가정 → O(10). |
| v5→v6 마이그레이션 | ≤ 200ms | addColumn ×2 = O(1) 메타데이터 작업. |
| 5탭 네비게이션 | layout 정상 | BottomAppBar + FAB centerDocked. label 2~3자 유지. |

---

## 10. Risks (Plan §7과 동기화)

| Risk | Design 대응 |
|------|------------|
| isDue weekly 주 경계 오류 | `todayMon` = `today.subtract(Duration(days: today.weekday - 1))` 정확 계산. 단위 테스트 2건 필수. |
| fl_chart BarChart 카테고리 많을 때 렌더 | 상위 5개 + 기타 합산. 카테고리 수 무관 O(5) 바. |
| 5탭 네비게이션 바 공간 | label 2자 ('리포트' → 3자이지만 한국어 UI 기준 OK). 실기기 확인. |
| 데이터 없는 연도 | monthlyTrend → 12개 항목 all zeros. YearSummaryCard → 0원 표시. 빈 상태 처리 없음. |
| budgetVsActual N+1 우려 | 카테고리 10개 이하 가정. 향후 증가 시 GROUP BY 쿼리로 최적화. |

---

## 11. Implementation Guide

### 11.1 의존성 추가

M5는 신규 패키지 없음 (fl_chart 이미 있음).

### 11.2 구현 순서 (의존 DAG)

```
[M5.1 fr67-recurrence]
1.  categories_screen.dart — _TopLevelTile children → ReorderableListView (FR-68)
2.  tables.dart — recurrenceType + dayOfWeek 컬럼 추가                   (schema v6)
3.  app_database.dart — schemaVersion=6, v5→v6 호출
4.  v5_to_v6.dart — addColumn ×2
5.  dart run build_runner build (Drift 코드 재생성)
6.  recurring_rule_repository.dart — isDue switch 분기 (FR-70)
7.  recurring_rule_form_sheet.dart — recurrence_type picker (FR-71)
8.  test/recurring_rule_test.dart — weekly/daily 4건 추가 (총 9건)

[M5.2 report-infra]
9.  analytics_repository.dart — DTOs + 4개 쿼리 메서드 (FR-72~75)
10. app/providers.dart — 4종 report providers 등록
11. app/router.dart — /reports 5번째 탭 추가 (FR-81)
12. test/integration/report_repository_test.dart — 3건
13. test/integration/migration_test.dart — v5→v6 1건 추가

[M5.3 report-ui]
14. analytics/ui/year_summary_card.dart (FR-79)
15. analytics/ui/monthly_trend_chart.dart (FR-77)
16. analytics/ui/monthly_category_bar_chart.dart (FR-78)
17. analytics/ui/budget_comparison_section.dart (FR-80)
18. analytics/ui/reports_screen.dart — 조립 + 연도 선택 (FR-76)
```

### 11.3 Session Guide (Module Map)

| Session | Scope Key | 포함 | 예상 LOC |
|---------|-----------|------|-------:|
| **session-1** | `fr67-recurrence` | categories_screen FR-68 + schema v6 + isDue switch + FormSheet picker + 단위 테스트 | ~250 |
| **session-2** | `report-infra` | analytics_repository 4 DTOs + 4 쿼리 + providers + router 5탭 + 통합 테스트 | ~350 |
| **session-3** | `report-ui` | 5개 UI 파일 (ReportsScreen + 4 위젯) | ~300 |

**총 ~900 LOC** / 3세션

### 11.4 검증 명령어 (M5 DoD)

```bash
dart run build_runner build --force-jit --delete-conflicting-outputs
flutter analyze              # 0 issues
flutter test                 # ~113건 (기존 101 + M5 신규 ~12)
flutter run                  # v5→v6 마이그레이션 + 5탭 확인
```

---

## 12. Open Questions

| # | Question | Owner | Resolve By |
|---|----------|-------|-----------|
| Q1 | ReportsScreen 연도 선택 최솟값 — 고정 5년 전 vs 첫 거래 연도? | 본인 | session-2 구현 전 |
| Q2 | MonthlyCategoryBarChart — 가로 스크롤 vs 세로 레이아웃? | 본인 | session-3 직전 |
| Q3 | 5탭일 때 FAB centerDocked 레이아웃 — 탭 2개 사이 FAB 위치 확인 필요 | 본인 | session-2 router 추가 시 실기기 확인 |

---

## 13. Decision Record

| 결정 | 선택 | 근거 |
|------|------|------|
| Architecture | Option A — analytics 폴더 확장 | 신규 feature 디렉터리 없이 최소 변경. M5 ~900 LOC 규모에 적합. |
| Report DTOs 위치 | analytics_repository.dart 인라인 | M4 BudgetStatus 패턴 일관성. 별도 domain 파일 오버헤드 없음. |
| isDue 확장 방식 | switch/case (recurrenceType string) | Drift TEXT 컬럼 + Dart enum 불필요. 3종(monthly/weekly/daily)으로 충분. |
| 리포트 탭 순서 | 계좌(3) 뒤에 리포트(4) 추가 | 기존 탭 순서 유지. 사용 빈도 낮은 리포트는 마지막. |
| BudgetVsActual 쿼리 | 카테고리별 개별 쿼리 (N쿼리) | 예산 카테고리 ≤ 10건 가정. 현재 데이터 규모에서 충분. 성능 이슈 시 GROUP BY로 교체. |
| 연도 선택 상태 | ReportsScreen 내부 local state | 앱 전역 상태 불필요. 화면 로컬로 충분. |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-04-30 | Initial M5 design (Option A — analytics 폴더 확장). 6신규 + 8수정 파일, ~900 LOC, 3세션. FR-68~82. | kyk@hunik.kr |
