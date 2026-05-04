---
template: design
version: 1.0
feature: budget-tracker-m4
cycle: M4
date: 2026-04-30
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.5.0"
level: Dynamic
architecture: Option A — Minimal (기존 폴더에 파일 추가, 모듈 경계 없음)
basePlan: docs/01-plan/features/budget-tracker-m4.plan.md
baseDesign: docs/02-design/features/budget-tracker-m3.design.md
---

# Budget Tracker — M4 Design Document

> **Architecture**: Minimal — 신규 feature 디렉터리 없이 기존 `dashboard/` + `analytics/` 폴더에 파일 추가. RecurringDue는 HomeScreen 내부 위젯. 예산 오버레이는 AnalyticsScreen 인라인 섹션.
>
> **M3 → M4 핵심 변경**: recurring_rules + budgets 2개 신규 테이블 (Schema v5) + 홈 배지 + RecurringDueSheet(내장) + budget_screen.dart + RecurringRulesScreen + 분석 탭 예산 섹션.

---

## Context Anchor (Plan Carry-Over)

| Key         | Value                                                                                               |
| ----------- | --------------------------------------------------------------------------------------------------- |
| **WHY**     | 반복 고정비 트리거 자동화 + 예산 초과 능동 경고 → 사후 확인이 아닌 사전 통제                        |
| **WHO**     | 본인 1인 (M1~M3 사용자). 매월 고정비 5-10건 + 카테고리별 예산 의식 있음                             |
| **RISK**    | (1) `isDue()` last_confirmed_at 날짜 비교 로직 (2) 예산 미설정 카테고리 처리 (3) v4→v5 마이그레이션 |
| **SUCCESS** | 홈 배지 → DueSheet insert / 분석 탭 예산 오버레이 / migration test 작성                             |
| **SCOPE**   | 반복거래(매월) + 예산(카테고리별) + FR-46 migration test + Minor backlog                            |

---

## 1. Overview

### 1.1 변경 요약 (M3 → M4)

```
M3 = 패턴 + 효율 + 해상도 (달력 + 템플릿 + 카테고리 계층)
M4 = 자동 + 통제 (반복 거래 알림 + 예산 한도)
```

| 영역      | M3                                     | M4 추가                                                                                                                                                                                                                        |
| --------- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Schema    | v4 (tx_templates + parent_category_id) | v5 + recurring_rules + budgets                                                                                                                                                                                                 |
| 홈 화면   | 잔액 + 수입/지출 + 순자산              | + 반복 거래 도래 배지 (조건부)                                                                                                                                                                                                 |
| 설정      | 거래 템플릿 관리 + 카테고리 관리       | + 반복 거래 관리 + 예산 관리                                                                                                                                                                                                   |
| 분석 탭   | 달력 + 도너츠 + 라인                   | + 예산 현황 섹션 (도너츠 아래)                                                                                                                                                                                                 |
| 신규 파일 | —                                      | dashboard/data/recurring_rule_repository.dart, dashboard/ui/{recurring_rules_screen, recurring_rule_form_sheet}.dart, analytics/data/budget_repository.dart, analytics/ui/budget_screen.dart, core/db/migrations/v4_to_v5.dart |

### 1.2 변경 없는 부분

| 영역           | 그대로                                      |
| -------------- | ------------------------------------------- |
| 회계 모델      | 4-type Tx + Accounts (변경 없음)            |
| Sheets 동기화  | one-way push (recurring/budget은 로컬 설정) |
| 상태관리       | Riverpod 2.x                                |
| 라우팅 구조    | 4탭 + FAB + /settings push                  |
| 기존 기능 전체 | M1~M3 코드 수정 없음 (확장만)               |

---

## 2. Architecture

### 2.1 파일 변경 맵 (Option A)

```
money_tracker_app/lib/
├── core/db/
│   ├── tables.dart                                   # ✏️ RecurringRules + Budgets 추가
│   ├── app_database.dart                             # ✏️ schemaVersion=5, v4→v5
│   └── migrations/
│       └── v4_to_v5.dart                             # 🆕 createTable ×2
├── features/
│   ├── dashboard/
│   │   ├── data/
│   │   │   └── recurring_rule_repository.dart        # 🆕 domain + DAO + repo
│   │   └── ui/
│   │       ├── home_screen.dart                      # ✏️ 배지 + _RecurringDueSheet
│   │       ├── recurring_rules_screen.dart            # 🆕 설정 sub-screen
│   │       └── recurring_rule_form_sheet.dart         # 🆕 생성/수정 폼
│   └── analytics/
│       ├── data/
│       │   ├── analytics_repository.dart             # ✏️ budgetOverlay() 추가
│       │   └── budget_repository.dart                # 🆕 domain + DAO + repo
│       └── ui/
│           ├── analytics_screen.dart                 # ✏️ 예산 섹션 추가
│           └── budget_screen.dart                    # 🆕 설정 sub-screen
├── app/
│   ├── providers.dart                                # ✏️ recurring + budget providers
│   └── router.dart                                   # ✏️ /settings/recurring + /settings/budget
└── features/settings/ui/
    └── settings_screen.dart                          # ✏️ 2 ListTile 추가
```

**신규 파일**: 6개 / **수정 파일**: 8개 / 예상 LOC: ~1,100

### 2.2 의존성 그래프

```
HomeScreen
  └── RecurringRuleRepository (watch dueRules)
        └── AppDatabase.recurringRules (DAO)
              └── AppDatabase.txTemplates (JOIN for name/amount display)

AnalyticsScreen
  └── AnalyticsRepository.budgetOverlay()
        └── AppDatabase.budgets + transactions (JOIN)
        └── AppDatabase.categories (JOIN for name)
```

---

## 3. Data Model (Schema v5 Delta)

### 3.1 신규: `recurring_rules` 테이블

```dart
// core/db/tables.dart 추가

// Design Ref: §3.1 — recurring_rules (M4 신규 v5). 매월 N일 도래 알림.
// isDue 체크: dayOfMonth <= today.day && lastConfirmedAt 이번달 미처리.
@DataClassName('RecurringRule')
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK → tx_templates. 템플릿에서 거래 정보 prefill.
  IntColumn get templateId => integer()
      .customConstraint('NOT NULL REFERENCES tx_templates(id)')();

  /// 1-28. 29-31 값은 UI에서 거부. 2월 안전을 위해 최대 28일.
  IntColumn get dayOfMonth => integer()();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  /// 가장 최근 확인(confirm 또는 skip) 시각.
  /// NULL = 한 번도 처리 안 함.
  /// 이번 달 처리 여부: lastConfirmedAt?.month == today.month && year 일치.
  DateTimeColumn get lastConfirmedAt => dateTime().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
```

### 3.2 신규: `budgets` 테이블

```dart
// Design Ref: §3.2 — budgets (M4 신규 v5). 카테고리별 월 한도.
// UNIQUE(category_id) — 카테고리당 하나의 한도만.
@DataClassName('Budget')
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK → categories. UNIQUE — 카테고리당 1행.
  IntColumn get categoryId => integer()
      .unique()
      .customConstraint('NOT NULL REFERENCES categories(id)')();

  /// 원(KRW). 양수만 허용 (UI에서 > 0 검증).
  IntColumn get monthlyLimit => integer()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
```

### 3.3 마이그레이션 v4 → v5

```dart
// core/db/migrations/v4_to_v5.dart
// Design Ref: §3.3 — v4→v5. 두 신규 테이블 동시 생성 (M3 패턴 확장).

import 'package:drift/drift.dart';
import '../app_database.dart';

class V4ToV5 {
  const V4ToV5._();

  static Future<void> apply(Migrator m, AppDatabase db) async {
    await m.createTable(db.recurringRules);
    await m.createTable(db.budgets);
  }
}
```

```dart
// app_database.dart 수정 부분
@override
int get schemaVersion => 5;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 3) await V2ToV3.apply(m, this);
    if (from < 4) await V3ToV4.apply(m, this);
    if (from < 5) await V4ToV5.apply(m, this);
  },
  beforeOpen: (_) async {
    await customStatement('PRAGMA foreign_keys = ON');
  },
);
```

---

## 4. Component Specifications

### 4.1 `RecurringRule` domain + DAO + Repository

```dart
// features/dashboard/data/recurring_rule_repository.dart
// Design Ref: §4.1 — RecurringRule domain + DAO + repo (Option A minimal).

// ── Domain ─────────────────────────────────────────────
class RecurringRule {
  const RecurringRule({
    required this.id,
    required this.templateId,
    required this.dayOfMonth,
    required this.isActive,
    required this.lastConfirmedAt,
    required this.templateName,  // JOIN from tx_templates
    this.templateAmount,         // nullable — 금액 미정 템플릿
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int templateId;
  final int dayOfMonth;
  final bool isActive;
  final DateTime? lastConfirmedAt;
  final String templateName;
  final int? templateAmount;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Plan SC-1: isDue 순수 함수 — 단위 테스트 필수.
  /// 조건: (1) isActive (2) dayOfMonth <= today.day
  ///       (3) lastConfirmedAt == null
  ///           OR lastConfirmedAt가 이번달 미만
  bool isDue(DateTime today) {
    if (!isActive) return false;
    if (dayOfMonth > today.day) return false;
    if (lastConfirmedAt == null) return true;
    final lc = lastConfirmedAt!;
    return lc.year < today.year ||
        (lc.year == today.year && lc.month < today.month);
  }
}

// ── Repository ──────────────────────────────────────────
class RecurringRuleRepository {
  RecurringRuleRepository(this._db);
  final AppDatabase _db;

  /// 활성 규칙 전체 + 템플릿 이름/금액 JOIN.
  Stream<List<RecurringRule>> watchAll() { ... }

  /// today 기준 도래한 규칙 목록 (isDue 필터링은 Dart에서).
  Future<List<RecurringRule>> getDue(DateTime today) async {
    final all = await watchAll().first;
    return all.where((r) => r.isDue(today)).toList();
  }

  Future<int> insert(RecurringRulesCompanion c) =>
      _db.into(_db.recurringRules).insert(c);

  Future<void> update(int id, RecurringRulesCompanion c) =>
      (_db.update(_db.recurringRules)..where((r) => r.id.equals(id)))
          .write(c);

  Future<void> delete(int id) =>
      (_db.delete(_db.recurringRules)..where((r) => r.id.equals(id))).go();

  /// 확인 or 스킵 — lastConfirmedAt을 today로 갱신.
  Future<void> markHandled(int id) =>
      (_db.update(_db.recurringRules)..where((r) => r.id.equals(id))).write(
        RecurringRulesCompanion(lastConfirmedAt: Value(DateTime.now())),
      );
}
```

### 4.2 `Budget` domain + Repository

```dart
// features/analytics/data/budget_repository.dart
// Design Ref: §4.2 — Budget domain + repo (Option A minimal).

class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.monthlyLimit,
    required this.categoryName,
  });
  final int id;
  final int categoryId;
  final int monthlyLimit;
  final String categoryName; // JOIN from categories
}

class BudgetStatus {
  const BudgetStatus({
    required this.categoryId,
    required this.categoryName,
    required this.spent,
    required this.limit,
  });
  final int categoryId;
  final String categoryName;
  final int spent;
  final int limit;

  double get ratio => limit > 0 ? spent / limit : 0.0;
  bool get isOver => spent > limit;
}

class BudgetRepository {
  BudgetRepository(this._db);
  final AppDatabase _db;

  /// categories JOIN. 예산 있는 카테고리만.
  Future<List<Budget>> getAll() async { ... }

  /// INSERT OR REPLACE 패턴 (UNIQUE category_id).
  Future<void> upsert(int categoryId, int monthlyLimit) =>
      _db.into(_db.budgets).insertOnConflictUpdate(
        BudgetsCompanion.insert(
          categoryId: categoryId,
          monthlyLimit: monthlyLimit,
        ),
      );

  Future<void> delete(int categoryId) =>
      (_db.delete(_db.budgets)
            ..where((b) => b.categoryId.equals(categoryId)))
          .go();
}
```

### 4.3 `AnalyticsRepository.budgetOverlay()`

```dart
// features/analytics/data/analytics_repository.dart 추가 메서드
// Design Ref: §4.3 — budgetOverlay. LEFT JOIN budgets+categories+monthly spend.

Future<List<BudgetStatus>> budgetOverlay({
  required DateTime month,
}) async {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);

  // 예산 있는 카테고리만 (INNER JOIN budgets)
  final budgets = await (_db
      .select(_db.budgets)
      .join([
        innerJoin(_db.categories,
            _db.categories.id.equalsExp(_db.budgets.categoryId)),
      ]))
      .get();

  if (budgets.isEmpty) return [];

  // 이번달 카테고리별 expense 합계
  final spending = <int, int>{};
  for (final row in budgets) {
    final catId = row.readTable(_db.categories).id;
    final monthlySpent = await _monthlySpentForCategory(catId, start, end);
    spending[catId] = monthlySpent;
  }

  return budgets.map((row) {
    final cat = row.readTable(_db.categories);
    final budget = row.readTable(_db.budgets);
    return BudgetStatus(
      categoryId: cat.id,
      categoryName: cat.name,
      spent: spending[cat.id] ?? 0,
      limit: budget.monthlyLimit,
    );
  }).toList()
    ..sort((a, b) => b.ratio.compareTo(a.ratio)); // 초과율 높은 순
}

Future<int> _monthlySpentForCategory(
    int categoryId, DateTime start, DateTime end) async {
  final rows = await (_db.select(_db.transactions)
        ..where((t) =>
            t.deletedAt.isNull() &
            t.type.equalsValue(TxType.expense) &
            t.categoryId.equals(categoryId) &
            t.occurredAt.isBiggerOrEqualValue(start) &
            t.occurredAt.isSmallerThanValue(end)))
      .get();
  return rows.fold(0, (sum, t) => sum + t.amount);
}
```

---

## 5. UI Specifications

### 5.1 HomeScreen — 반복 거래 도래 배지

기존 `_DashboardBody` ListView에 조건부 배지 카드 삽입:

```
┌─────────────────────────────────────┐
│ 머니 머니                     ⚙️    │
├─────────────────────────────────────┤
│ 가용 현금                           │
│ ₩ 3,250,000                        │
│ 현금 ₩ 4,600,000 · 카드 -₩1,350,000│
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ 📋 반복 거래 2건 처리 필요   ▶  │ │  ← _RecurringDueBadge (조건부)
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│ [이번 달 수입]  [이번 달 지출]      │
│ ...                                │
└─────────────────────────────────────┘
```

- `ref.watch(dueRecurringRulesProvider)` — count > 0일 때만 표시
- 배지 색상: `colorScheme.secondaryContainer` (주의 but not error)
- 탭 → `showModalBottomSheet` → `_RecurringDueSheet`

### 5.2 RecurringDueSheet (HomeScreen 내부 private widget)

```
┌─────────────────────────────────────┐
│   ━━━━━ (드래그 핸들)                │
│ 처리할 반복 거래                     │
│ 도래한 항목을 확인하거나 건너뛰세요  │
├─────────────────────────────────────┤
│ 📋 월세                             │
│ 매월 25일  · ₩ 850,000              │
│           [건너뜀]  [입력 화면으로 ▶]│
├─────────────────────────────────────┤
│ 📋 통신비                           │
│ 매월 15일  · 금액 미정              │
│           [건너뜀]  [입력 화면으로 ▶]│
└─────────────────────────────────────┘
```

- "입력 화면으로" → `context.push('/input', extra: {'templateId': rule.templateId})`
  - InputScreen이 templateId extra를 받아 applyTemplate 자동 호출 (M3 기존 로직 재사용)
- "건너뜀" → `repository.markHandled(rule.id)` → 배지 count 감소
- "입력 화면으로" 탭 후 거래 저장 성공 → InputScreen에서 callback으로 `repository.markHandled` 호출
  - InputScreen의 저장 성공 후 처리: `context.pop(true)` → DueSheet에서 `result == true`이면 markHandled
- 모든 항목 처리 → 시트 자동 닫힘

### 5.3 RecurringRulesScreen (설정 sub)

```
┌─────────────────────────────────────┐
│ ← 반복 거래 관리                     │
├─────────────────────────────────────┤
│ 반복 거래를 등록하면 결제일에         │
│ 홈 화면에 알림이 표시됩니다          │
├─────────────────────────────────────┤
│ 📋 월세            매월 25일  ON  ⋮ │
│ 📋 통신비          매월 15일  ON  ⋮ │
│ 📋 넷플릭스        매월 1일   OFF ⋮ │
├─────────────────────────────────────┤
│        [+ 반복 거래 추가]            │
└─────────────────────────────────────┘
```

- ⋮ 메뉴: 수정 / 삭제 / 활성화 토글
- "추가" → `RecurringRuleFormSheet` 모달

### 5.4 RecurringRuleFormSheet

```
┌─────────────────────────────────────┐
│   반복 거래 추가                     │
├─────────────────────────────────────┤
│ 템플릿  [월세 ▾]                    │  템플릿 picker (M3 TemplatePicker 재사용)
│ 결제일  [25 ▾]                      │  1-28 드롭다운
│                                     │
│         [취소]      [저장]           │
└─────────────────────────────────────┘
```

- 템플릿 picker: M3의 `TemplatePickerSheet` 재사용 가능
- dayOfMonth: `DropdownButton<int>` 1-28

### 5.5 BudgetScreen (설정 sub)

```
┌─────────────────────────────────────┐
│ ← 예산 관리                          │
├─────────────────────────────────────┤
│ 카테고리별 월 한도를 설정하면        │
│ 분석 탭에서 초과 여부를 확인할 수   │
│ 있습니다                            │
├─────────────────────────────────────┤
│ 식비         ₩ 500,000  [수정]       │
│ 교통비       ₩ 100,000  [수정]       │
│ 쇼핑         미설정      [설정]       │
│ 외식         미설정      [설정]       │
│ ...                                │
└─────────────────────────────────────┘
```

- expense kind 카테고리만 표시 (income/transfer는 의미 없음)
- "설정"/"수정" 탭 → `showDialog(NumberInputDialog)` — 금액 입력 후 저장
- 삭제: [수정] 장누르기 or 별도 clear 버튼

### 5.6 AnalyticsScreen — 예산 현황 섹션

도너츠 차트 카드 아래에 신규 섹션 추가:

```
┌─────────────────────────────────────┐
│ 카테고리 비중                        │
│ [도너츠 차트]                       │  ← 기존
│ ...                                │
├─────────────────────────────────────┤
│ 예산 현황                           │  ← 🆕 _BudgetOverlaySection
│                                     │
│ 식비   [███████░░░] 70%             │
│        ₩ 350,000 / ₩ 500,000       │
│                                     │
│ 교통   [██████████] 105% ⚠️          │
│        ₩ 105,000 / ₩ 100,000       │
│                                     │
│ 쇼핑   [█░░░░░░░░░] 10%            │
│        ₩ 15,000 / ₩ 150,000        │
└─────────────────────────────────────┘
```

- `ref.watch(budgetOverlayProvider(_selectedMonth))` — 월 선택과 연동
- 예산 설정된 카테고리 없으면 섹션 전체 숨김 (empty state 없음)
- 바: `LinearProgressIndicator` value = `ratio.clamp(0, 1)`
- 초과(ratio > 1.0): 바 색상 `colorScheme.error`, ⚠️ 아이콘

---

## 6. State Management (M4 신규 Providers)

```dart
// app/providers.dart 추가

// ── Recurring Rules ──────────────────────────────────────
final recurringRuleRepositoryProvider = Provider<RecurringRuleRepository>(
  (ref) => RecurringRuleRepository(ref.watch(appDatabaseProvider)),
);

final allRecurringRulesProvider =
    StreamProvider<List<RecurringRule>>((ref) {
  return ref.watch(recurringRuleRepositoryProvider).watchAll();
});

final dueRecurringRulesProvider =
    FutureProvider<List<RecurringRule>>((ref) {
  return ref
      .watch(recurringRuleRepositoryProvider)
      .getDue(DateTime.now());
});

// ── Budget ───────────────────────────────────────────────
final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(appDatabaseProvider)),
);

final allBudgetsProvider = FutureProvider<List<Budget>>((ref) {
  return ref.watch(budgetRepositoryProvider).getAll();
});

final budgetOverlayProvider =
    FutureProvider.family<List<BudgetStatus>, DateTime>((ref, month) {
  return ref
      .watch(analyticsRepositoryProvider)
      .budgetOverlay(month: month);
});
```

---

## 7. Test Plan

### 7.1 Unit Tests (M4 신규)

**RecurringRule.isDue — 순수 함수 테스트 (5건)**

```dart
// 1. isActive = false → always false
// 2. dayOfMonth 15, today 10 → false (아직 안 됨)
// 3. dayOfMonth 15, today 20, lastConfirmedAt = null → true
// 4. dayOfMonth 15, today 20, lastConfirmedAt = 이번달 16일 → false (이미 처리)
// 5. dayOfMonth 15, today 20, lastConfirmedAt = 전월 15일 → true (이번달 미처리)
```

**BudgetStatus.ratio — 경계값 테스트 (3건)**

```dart
// 1. spent 350_000, limit 500_000 → ratio = 0.7
// 2. spent 105_000, limit 100_000 → ratio = 1.05, isOver = true
// 3. spent 0, limit 0 → ratio = 0.0 (zero division guard)
```

### 7.2 Integration Tests (M4 신규)

**RecurringRuleRepository (3건)**

```dart
// test/integration/recurring_rule_repository_test.dart
// 1. insert → getDue(today, dayOfMonth=today.day) → 1건 반환
// 2. markHandled → getDue → 0건 (이번달 처리됨)
// 3. isActive=false → getDue → 0건
```

**BudgetRepository (2건)**

```dart
// 1. upsert → getAll → 1건, monthlyLimit 정확
// 2. upsert 같은 categoryId 두 번 → getAll → 1건 (UNIQUE 갱신)
```

### 7.3 Migration Tests (FR-65)

```dart
// test/integration/migration_test.dart (신규 or 기존 파일에 추가)
// v2→v3: accounts.due_day 컬럼 추가 + 기존 행 보존
// v3→v4: tx_templates 신규 + categories.parent_category_id 추가
// v4→v5: recurring_rules + budgets 신규 테이블 + 기존 데이터 보존
// 각 마이그레이션: in-memory Drift SchemaVerifier 활용
```

### 7.4 Manual Verification (M4 DoD)

- [ ] M3 디바이스(v4 db) → v5 마이그레이션 실행 후 기존 거래/템플릿/카테고리 0 손실
- [ ] 반복 거래 규칙 생성 (매월 오늘 날짜) → 즉시 홈 배지 표시
- [ ] RecurringDueSheet → "입력 화면으로" → 폼 prefill 확인 → 저장 → 배지 감소
- [ ] 설정 → 예산 관리 → 식비 50만원 설정 → 분석 탭 → 예산 현황 섹션 표시
- [ ] 분석 탭 예산 바에서 초과(⚠️) 카테고리 색상 변경 확인
- [ ] flutter analyze 0 issues

---

## 8. Routing (추가분)

```dart
// app/router.dart 추가 — /settings 하위 routes

GoRoute(
  path: 'recurring',
  builder: (_, _) => const RecurringRulesScreen(),
),
GoRoute(
  path: 'budget',
  builder: (_, _) => const BudgetScreen(),
),
```

기존 설정 push 흐름 유지:

- `context.push('/settings/recurring')` from SettingsScreen
- `context.push('/settings/budget')` from SettingsScreen

---

## 9. Performance & Security

| 영역                  | 목표      | 전략                                                                                 |
| --------------------- | --------- | ------------------------------------------------------------------------------------ |
| 홈 도래 체크          | ≤ 100ms   | getDue = watchAll().first + Dart filter (active rules 5-10건 가정)                   |
| 분석 탭 예산 오버레이 | ≤ 300ms   | 카테고리별 월 집계 = 기존 categoryDonut과 동일 쿼리 패턴. budgetOverlayProvider 캐시 |
| v4→v5 마이그레이션    | ≤ 200ms   | createTable×2 = O(1) 메타데이터 작업                                                 |
| Security              | 변경 없음 | M1~M3 정책 유지                                                                      |

---

## 10. Risks (Plan §7과 동기화)

| Risk                                 | Design 대응                                                                                                                                                     |
| ------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `isDue()` 중복 insert                | isDue 순수 함수로 추출 + 5건 단위 테스트 필수. `markHandled` = confirm과 skip 동일 함수 (구분 불필요)                                                           |
| InputScreen templateId extra 연동    | InputScreen이 이미 `extra: {'templateId': id}` 패턴 사용 (M3 TemplatePicker에서 확인 필요). 아니면 `context.push('/input?templateId=$id')` query param으로 대안 |
| 예산 없는 카테고리 → budgetOverlay   | `INNER JOIN budgets` 쿼리로 예산 설정된 카테고리만 반환. List 비면 AnalyticsScreen에서 섹션 전체 숨김. null 처리 없음.                                          |
| v4→v5 테이블 2개 동시 생성           | V3ToV4와 동일 패턴. in-memory migration test로 사전 검증 (FR-65).                                                                                               |
| RecurringDueSheet + InputScreen 왕복 | `context.push('/input', extra: ...)` + pop result 패턴. DueSheet에서 result 리스닝 후 markHandled.                                                              |

---

## 11. Implementation Guide

### 11.1 의존성 추가

M4는 신규 패키지 없음 (기존 Drift + Riverpod + GoRouter 활용).

### 11.2 구현 순서 (의존 DAG)

```
1. tables.dart — RecurringRules + Budgets 추가                   (session-1)
2. app_database.dart — schemaVersion=5, v4→v5 호출               (session-1)
3. v4_to_v5.dart — createTable ×2                               (session-1)
4. dart run build_runner build (Drift 코드 재생성)               (session-1)
5. recurring_rule_repository.dart — domain + isDue + repo        (session-1)
6. providers.dart — recurring providers 등록                     (session-1)
7. home_screen.dart — _RecurringDueBadge + _RecurringDueSheet   (session-1)
8. recurring_rules_screen.dart — 설정 목록 화면                  (session-2)
9. recurring_rule_form_sheet.dart — 생성/수정 폼                 (session-2)
10. settings_screen.dart — "반복 거래 관리" ListTile 추가        (session-2)
11. router.dart — /settings/recurring 추가                       (session-2)
12. budget_repository.dart — domain + repo                       (session-3)
13. analytics_repository.dart — budgetOverlay() 추가             (session-3)
14. budget_screen.dart — 설정 목록 화면                          (session-3)
15. settings_screen.dart — "예산 관리" ListTile 추가             (session-3)
16. router.dart — /settings/budget 추가                          (session-3)
17. providers.dart — budget providers 등록                        (session-3)
18. analytics_screen.dart — 예산 현황 섹션 추가                  (session-4)
19. test/integration/migration_test.dart — FR-65                 (session-5)
20. daily_calendar.dart — _DayCell.onTap minor fix               (session-5)
21. categories_screen.dart — 자식 drag-reorder (FR-67)           (session-5)
```

### 11.3 Session Guide (Module Map)

| Session       | Scope Key          | 포함                                                                                                                                               | 예상 LOC |
| ------------- | ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------- | -------: |
| **session-1** | `recurring-schema` | tables.dart + app_database.dart + v4_to_v5.dart + build_runner + recurring_rule_repository.dart + providers(recurring) + home_screen 배지+DueSheet |     ~400 |
| **session-2** | `recurring-mgmt`   | recurring_rules_screen.dart + recurring_rule_form_sheet.dart + settings/router 추가                                                                |     ~220 |
| **session-3** | `budget-setup`     | budget_repository.dart + analytics_repository.budgetOverlay + budget_screen.dart + settings/router + providers(budget)                             |     ~280 |
| **session-4** | `budget-analytics` | analytics_screen.dart 예산 현황 섹션                                                                                                               |     ~150 |
| **session-5** | `migration-tests`  | migration_test.dart (FR-65, 6건) + \_DayCell fix + categories drag-reorder (FR-67)                                                                 |     ~150 |

**총 ~1,200 LOC** (Option A이지만 UI 컴포넌트로 Plan ~900보다 약 30% 증가 예상).

### 11.4 검증 명령어 (M4 DoD)

```bash
dart run build_runner build --force-jit --delete-conflicting-outputs
flutter analyze              # 0 issues
flutter test                 # 기존 ~104 + M4 신규 ~13 = ~117건
flutter test test/integration/migration_test.dart  # FR-65 6건
flutter run                  # v4→v5 마이그레이션 실증
```

---

## 12. Open Questions

| #   | Question                                                                                                  | Owner | Resolve By                                       |
| --- | --------------------------------------------------------------------------------------------------------- | ----- | ------------------------------------------------ |
| Q1  | InputScreen의 templateId extra 방식 — `context.push('/input', extra: {'templateId': id})` vs query param? | 본인  | session-1 구현 전 (기존 코드 확인)               |
| Q2  | BudgetScreen에서 한도 입력 UI — AlertDialog 숫자 입력 vs 인라인 TextField?                                | 본인  | session-3 직전                                   |
| Q3  | 반복 거래 배지 위치 — AppBar actions 칩 vs 홈 body 카드?                                                  | 본인  | session-1 직전 (아래 §5.1 기본 body 카드로 설계) |

---

## 13. Decision Record

| 결정               | 선택                        | 근거                                                                                            |
| ------------------ | --------------------------- | ----------------------------------------------------------------------------------------------- |
| Architecture       | Option A (Minimal)          | M4 규모(~1,200 LOC)에 신규 모듈 디렉터리는 오버킬. 기존 dashboard/analytics 폴더에 흡수로 충분. |
| RecurringDue UI    | HomeScreen 내부 위젯        | 별도 파일 만들지 않음. DueSheet는 홈 전용 UI, 재사용 없음.                                      |
| isDue 순수 함수    | RecurringRule 도메인 메서드 | 사이드이펙트 없는 날짜 비교. 단위 테스트 용이.                                                  |
| markHandled        | confirm + skip 동일 함수    | 결과는 동일 (last_confirmed_at 갱신). 구분할 도메인 이유 없음.                                  |
| 예산 오버레이      | AnalyticsScreen 인라인      | 별도 위젯 파일 불필요. 분석 화면 전용, 재사용 없음.                                             |
| budgetOverlay 쿼리 | INNER JOIN budgets          | 예산 없는 카테고리는 자동 제외. null 처리 없음.                                                 |
| InputScreen 연동   | extra 패턴 또는 query param | Open Q1 — 기존 코드 확인 후 결정                                                                |

---

## Version History

| Version | Date       | Changes                                                                                |
| ------- | ---------- | -------------------------------------------------------------------------------------- |
| 1.0     | 2026-04-30 | Initial M4 design (Option A — Minimal). 6 신규 + 8 수정 파일, ~1,200 LOC, 5 세션 구분. |
