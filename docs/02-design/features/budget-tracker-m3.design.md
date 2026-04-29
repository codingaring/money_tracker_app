---
template: design
version: 1.0
feature: budget-tracker-m3
cycle: M3
date: 2026-04-29
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.4.0"
level: Dynamic
architecture: Option C — Pragmatic (templates 신규 모듈 + 달력은 analytics 흡수, M2 철학 동일)
basePlan: docs/01-plan/features/budget-tracker-m3.plan.md
baseDesign: docs/02-design/features/budget-tracker-m2.design.md
---

# Budget Tracker — M3 Design Document

> **Architecture**: Pragmatic (M1·M2와 동일 철학). 새 도메인(템플릿)은 모듈 신설, 같은 책임(분석·카테고리)은 기존 모듈에 흡수.
>
> **M2 → M3 핵심 변경**: 신규 `features/templates/` 모듈 + `features/categories/ui/` 신규 + Drift v3→v4 마이그레이션 (`tx_templates` 신설 + `categories.parent_category_id` 추가) + `AnalyticsRepository.dailyExpenseMap()` + 카테고리 도너츠 rollup + `DailyCalendar` 위젯 + `CategoryPicker` 위젯 + Sheets `templates` 시트 + tx 시트 카테고리 2-컬럼 분리 + 통합 테스트 8건.

---

## Context Anchor (Plan Carry-Over)

| Key | Value |
|-----|-------|
| **WHY** | 일자별 시야 추가 + 반복 입력 부담 제거 → 매일 사용성 강화 |
| **WHO** | 본인 1인 (M1·M2 사용자, 1-2개월 데이터 누적) |
| **RISK** | Drift v3→v4 두 번째 마이그레이션 / Sheets templates 시트 신규 / 템플릿 amount NULL 처리 / 달력 month picker state 공유 |
| **SUCCESS** | 일별 합계 정확 / 템플릿 영구 재사용 / Sheets 동기화 / M2 데이터 0 손실 |
| **SCOPE** | 일별 달력 + 템플릿 CRUD + 사용 picker + Sheets sync + 마이그레이션 v4. 반복 자동·예산은 M4. |

---

## 1. Overview

### 1.1 변경 요약 (M2 → M3)

```
M2 = 이해 + 예측 (분석 차트, 카드 결제 예측, 검색)
M3 = 패턴 + 효율 (일별 달력 회고, 템플릿 반복 입력 제거)
```

| 영역 | M2 | M3 추가 |
|------|------|---------|
| Schema | 5 테이블 (v3) | + `tx_templates` 테이블 + `categories.parent_category_id` 컬럼 (v4 단일 마이그레이션 2 변경 동시) |
| Modules | 9 | + `features/templates/` 신규 + `features/categories/ui/` 신규 |
| 탭 | 4 | 동일 |
| 설정 sub | info만 | + "거래 템플릿 관리" + "카테고리 관리" 2 sub-screen |
| 입력 흐름 | InputScreen → 폼 → 저장 | + 상단 "📋 템플릿에서" picker / 카테고리는 cascading 2-step |
| 분석 도너츠 | leaf 카테고리별 합계 | leaf → parent rollup 집계 (대분류로 합쳐짐) |
| Drift 마이그레이션 | v2→v3 (1건, addColumn) | + v3→v4 (createTable + addColumn) |
| Sheets 시트 | 3 | + `templates` (4번째) |
| Sheets tx 컬럼 | 9 cols (A:I) | 10 cols (A:J) — `category_parent` 신규 D + `category` 기존 leaf 이동 E |
| 통합 테스트 | TransactionRepository 5건 | + TemplateRepository 4 + Category hierarchy 4 + dailyExpenseMap 단위 4 + categoryDonut rollup 단위 2 |

### 1.2 변경 없는 부분

| 영역 | 그대로 |
|------|--------|
| 회계 모델 | 4-type Tx + Accounts |
| 잔액 갱신 | atomic via AccountsDao |
| 라우팅 | 4 branch + center FAB + push routes (/input, /settings) — `/settings/templates` sub-route만 추가 |
| 상태관리 | Riverpod 2.x |
| 테마 | M2 정착 (hot pink #FF1F6E + cyan #13C2F0 + SUIT) |
| 4 시트 sync | accounts/transactions/monthly_summary 패턴 동일 |

---

## 2. Architecture

### 2.1 모듈 분할 (M3 추가분)

```
money_tracker_app/lib/
├── features/
│   ├── templates/                                # 🆕 신규 모듈
│   │   ├── domain/
│   │   │   └── tx_template.dart                  # 🆕 (값 객체)
│   │   ├── data/
│   │   │   ├── templates_dao.dart                # 🆕
│   │   │   └── template_repository.dart          # 🆕
│   │   └── ui/
│   │       ├── templates_screen.dart             # 🆕 (설정 sub: list + reorder + 추가)
│   │       ├── template_form_sheet.dart          # 🆕 (생성/수정 BottomSheet)
│   │       └── template_picker_sheet.dart        # 🆕 (Input에서 호출)
│   ├── analytics/
│   │   ├── data/analytics_repository.dart        # ✏️ +dailyExpenseMap() + categoryDonut rollup by parent
│   │   └── ui/
│   │       ├── daily_calendar.dart               # 🆕 (월 그리드 + heatmap)
│   │       └── analytics_screen.dart             # ✏️ +DailyCalendar 통합
│   ├── categories/
│   │   ├── domain/category.dart                  # ✏️ +parent helper extension
│   │   ├── data/category_repository.dart         # ✏️ +listTopLevel/listChildren/setParent/reorder
│   │   └── ui/                                   # 🆕 신규 sub
│   │       ├── categories_screen.dart            # 🆕 (설정 sub: list + parent expand + drag-reorder)
│   │       ├── category_form_sheet.dart          # 🆕 (생성/수정 BottomSheet, parent dropdown)
│   │       └── category_picker.dart              # 🆕 (cascading 2-step picker — 공유)
│   ├── transactions/ui/
│   │   ├── input_screen.dart                     # ✏️ "📋 템플릿에서" 버튼 + 카테고리 chip → CategoryPicker
│   │   └── filter_chips.dart                     # ✏️ 카테고리 chip → CategoryPicker
│   └── settings/ui/
│       └── settings_screen.dart                  # ✏️ "거래 템플릿 관리" + "카테고리 관리" entries
└── core/db/
    ├── tables.dart                               # ✏️ +TxTemplates 테이블 + Categories.parentCategoryId
    ├── app_database.dart                         # ✏️ schemaVersion=4 + onUpgrade
    └── migrations/
        └── v3_to_v4.dart                         # 🆕 createTable(txTemplates) + addColumn(categories.parentCategoryId)
```

```
lib/infrastructure/sheets/
└── sheet_layout.dart                             # ✏️ +templatesSheet, +templatesHeader, txHeader 10 cols (+category_parent), txAppendRange A:J

lib/features/sync/service/
└── sync_service.dart                             # ✏️ +_pushTemplatesSnapshot, _txToRow에 parentName 추가

lib/app/
├── providers.dart                                # ✏️ +templates/categories/dailyMap providers
└── router.dart                                   # ✏️ /settings/templates + /settings/categories push routes
```

**신규 파일**: 12개 / **수정 파일**: 9개 / 예상 LOC: ~1,800

### 2.2 의존성 그래프 (변경분만)

```
                ┌────────────────────────────┐
                │  UI                         │
                │  + TemplatesScreen           │
                │  + TemplateFormSheet         │
                │  + TemplatePickerSheet       │
                │  + DailyCalendar             │
                │  + InputScreen(picker btn)   │
                │  + AnalyticsScreen(calendar) │
                │  + SettingsScreen(entry)     │
                └─────────┬──────────────────┘
                          │
       ┌──────────────────┼──────────────────┐
       ▼                  ▼                  ▼
┌────────────┐    ┌─────────────┐    ┌──────────────┐
│Template    │    │Analytics    │    │M1·M2 existing│
│Repository  │    │Repository   │    │repos         │
│ 🆕         │    │ ✏️ +dailyMap│    │              │
└─────┬──────┘    └──────┬──────┘    └──────────────┘
      │                  │
      ▼                  │
┌────────────┐           │
│TemplatesDao│           │
│ 🆕         │           │
└─────┬──────┘           │
      │                  │
      └──────────────────┴───────────────┐
                                         ▼
                                  ┌──────────────┐
                                  │ AppDatabase  │
                                  │ (Drift v4)   │
                                  └──────────────┘
```

### 2.3 레이어 책임 (M3 추가)

| 레이어 | 신규 책임 |
|--------|----------|
| `templates/data/templates_dao` | tx_templates CRUD + sortOrder/lastUsedAt watch |
| `templates/data/template_repository` | 비즈니스 로직 — create/update/delete/reorder/markUsed |
| `categories/data/category_repository` | hierarchy 조회 — listTopLevel/listChildren/setParent/reorder. M1 baseline에 hierarchy 메서드 추가 |
| `categories/ui/category_picker` | cascading 2-step picker — 대분류 chip → 소분류 chip (있으면). InputScreen·TemplateForm·FilterChip 공유 |
| `categories/ui/categories_screen` | 카테고리 관리 sub — 대분류 expand 형식, 자식 list, drag-reorder |
| `analytics/data/analytics_repository.dailyExpenseMap` | 월별 일자별 expense 합계 (Map<DateTime, int>) |
| `analytics/data/analytics_repository.categoryDonut` | leaf → parent rollup 집계 (소분류는 부모로 합쳐짐) |
| `analytics/ui/daily_calendar` | 7×6 그리드 + heatmap + 셀 탭 callback |
| `infrastructure/sheets/sync_service._pushTemplatesSnapshot` | templates 시트 overwrite snapshot |
| `infrastructure/sheets/sync_service._txToRow` | tx 행에 `category_parent` (D) + `category` (E) 분리 매핑 |
| `core/db/migrations/v3_to_v4` | createTable(txTemplates) + addColumn(categories.parentCategoryId) 동시 적용 |

---

## 3. Data Model (Drift v4 Delta)

### 3.1 신규: `tx_templates` 테이블

| 컬럼 | Type | NULL | Default | 설명 |
|------|------|:----:|---------|------|
| id | INTEGER PK | No | autoIncrement | |
| name | TEXT UNIQUE | No | — | 템플릿 이름 (1-40자) |
| type | TEXT | No | — | TxType enum (expense/income/transfer/valuation) |
| amount | INTEGER | **Yes** | NULL | nullable — NULL이면 InputScreen에서 사용자 입력 대기 |
| from_account_id | INTEGER FK | Yes | NULL | accounts(id) — type별 use |
| to_account_id | INTEGER FK | Yes | NULL | accounts(id) |
| category_id | INTEGER FK | Yes | NULL | categories(id) — expense/income만 |
| memo | TEXT | Yes | NULL | |
| sort_order | INTEGER | No | 0 | 사용자 수동 정렬 |
| last_used_at | DATETIME | Yes | NULL | 사용 시 자동 갱신. picker에서 desc 정렬 (NULL은 가장 아래) |
| created_at | DATETIME | No | now | |
| updated_at | DATETIME | No | now | |

**제약**:
- `name`은 unique (중복 방지)
- type별 from/to/category 유효성은 application 레이어에서 검증 (DB constraint X — 유연성)
- amount > 0 또는 NULL (DB CHECK 안 걸음, NewTransaction.validate가 사용 시점에 잡음)

### 3.2 변경: `categories` 테이블

| 컬럼 | Type | NULL | Default | 설명 |
|------|------|:----:|---------|------|
| 기존 5 컬럼 | — | 유지 | — | id/name/kind/is_fixed/sort_order |
| **`parent_category_id`** | INTEGER FK | **Yes** | NULL | **🆕 v4** self-FK — categories(id), ON DELETE SET NULL. NULL = 대분류 / 값 있음 = 소분류 |

**제약**:
- 기존 17개 시드는 모두 parent_category_id = NULL (대분류만)
- 사용자가 관리 화면에서 새 카테고리 추가 시 parent 지정 가능
- 순환 방지: UI에서 부모 지정 시 children 트리 검사 — A를 B의 부모로 지정 시 B의 자손에 A가 있으면 거부 (단, 2-level 강제 시 부모는 NULL인 카테고리만 가리킬 수 있도록 해서 자동 차단)

### 3.3 마이그레이션 v3 → v4 (2 변경 동시)

```dart
// core/db/migrations/v3_to_v4.dart
import 'package:drift/drift.dart';
import '../app_database.dart';

class V3ToV4 {
  const V3ToV4._();

  /// Adds tx_templates table + categories.parent_category_id column.
  /// Both changes idempotent — Drift's createTable/addColumn skip if exists.
  static Future<void> apply(Migrator m, AppDatabase db) async {
    await m.createTable(db.txTemplates);
    await m.addColumn(db.categories, db.categories.parentCategoryId);
  }
}
```

```dart
// app_database.dart 수정 부분
@override
int get schemaVersion => 4;

@override
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 3) await V2ToV3.apply(m, this);
        if (from < 4) await V3ToV4.apply(m, this);
      },
      beforeOpen: (_) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
```

**검증 패턴** (M3.5 세션):
1. M2 디바이스 DB (v3)에 직접 flutter run → 자동 마이그레이션 → tx_templates 테이블 + categories.parent_category_id 컬럼 존재 확인
2. 기존 거래/계좌/카테고리 0 손실 검증 (BalanceReconciler 통과)
3. v3→v4 in-memory 테스트로 사전 검증 (두 변경 모두)
4. 기존 17개 카테고리 모두 parent_category_id = NULL인지 확인

### 3.4 Sheets `templates` 시트 신설

| 컬럼 | 매핑 |
|------|------|
| A: name | template.name |
| B: type | TxType.name |
| C: amount | template.amount ?? '' |
| D: from_account | accounts[fromAccountId].name ?? '' |
| E: to_account | accounts[toAccountId].name ?? '' |
| F: category | categories[categoryId].name ?? '' |
| G: memo | template.memo ?? '' |
| H: sort_order | template.sortOrder |
| I: last_used_at | template.lastUsedAt?.toIso8601String() ?? '' |

`SheetLayout.templatesSheet = 'templates'` + `templatesHeader = ['name','type','amount','from_account','to_account','category','memo','sort_order','last_used_at']` + `templatesOverwriteRange = 'templates!A1:I'`.

`SyncService._pushTemplatesSnapshot` = accounts 패턴과 동일 (overwrite snapshot, ensureSheet 멱등).

**기존 사용자**: 첫 동기화 시 ensureSheet이 시트+헤더 자동 생성 (영향 없음).

### 3.5 Sheets `transactions` 시트 카테고리 분리

```
Before (M2): A:date | B:type | C:amount | D:category | E:from_account | F:to_account | G:memo | H:tx_id | I:synced_at  (9 cols)
After  (M3): A:date | B:type | C:amount | D:category_parent | E:category | F:from_account | G:to_account | H:memo | I:tx_id | J:synced_at  (10 cols)
```

| 컬럼 | 매핑 |
|------|------|
| A: date | tx.occurredAt |
| B: type | TxType.name |
| C: amount | tx.amount |
| **D: category_parent** | **🆕** parent.name (parent NULL이면 leaf 자신, leaf NULL이면 '') |
| E: category | leaf.name (parent NULL이면 빈 칸 '대분류만') |
| F-J | from_account / to_account / memo / tx_id / synced_at (기존 E-I) |

`SheetLayout` 변경:
- `txHeader` 9 → 10 cols (D 위치에 'category_parent' 삽입)
- `txAppendRange` `transactions!A:I` → `transactions!A:J`
- `txIdColIdx` 7 → 8 (tx_id 위치 D→I로 이동)
- `txIdSearchRange` `transactions!H:H` → `transactions!I:I`
- `txRowRange(n)` `A{n}:I{n}` → `A{n}:J{n}`

**기존 사용자 호환** (M3.5에서 결정 필요):
- 시트는 append-only이므로 기존 행은 9 cols 그대로
- 새 행 append는 10 cols
- 헤더 행만 강제 갱신 — `_ensureTxHeader` 헬퍼 추가 (한 번만 update). 또는 사용자에게 sheet 헤더 D 컬럼 직접 추가 안내

---

## 4. Component Specifications

### 4.1 `TxTemplate` 도메인 객체

`@DataClassName('TxTemplate')` Drift 자동 생성 (createdAt/updatedAt 등 모두 포함). 별도 도메인 클래스 없이 Drift row를 그대로 사용 (M1·M2 패턴 유지).

값 객체가 필요하면 `templates/domain/tx_template.dart`에 helper extension만:

```dart
// 사용 가능 여부 체크
extension TxTemplateValidation on TxTemplate {
  /// All referenced FK IDs are still valid in the current DB.
  bool isResolvableWith({
    required Set<int> validAccountIds,
    required Set<int> validCategoryIds,
  }) {
    if (fromAccountId != null && !validAccountIds.contains(fromAccountId)) {
      return false;
    }
    if (toAccountId != null && !validAccountIds.contains(toAccountId)) {
      return false;
    }
    if (categoryId != null && !validCategoryIds.contains(categoryId)) {
      return false;
    }
    return true;
  }
}
```

### 4.2 `TemplatesDao`

```dart
@DriftAccessor(tables: [TxTemplates])
class TemplatesDao extends DatabaseAccessor<AppDatabase>
    with _$TemplatesDaoMixin {
  TemplatesDao(super.db);

  Stream<List<TxTemplate>> watchAll() {
    return (select(txTemplates)
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  Stream<List<TxTemplate>> watchByLastUsed() {
    // NULLS LAST — never-used templates appear after recently-used ones.
    return (select(txTemplates)
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.lastUsedAt,
                  mode: OrderingMode.desc,
                  nulls: NullsOrder.last,
                ),
            (t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .watch();
  }

  Future<List<TxTemplate>> readAll() {
    return (select(txTemplates)
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
  }

  Future<TxTemplate?> findById(int id) =>
      (select(txTemplates)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertOne(TxTemplatesCompanion data) =>
      into(txTemplates).insert(data);

  Future<int> updateById(int id, TxTemplatesCompanion patch) =>
      (update(txTemplates)..where((t) => t.id.equals(id)))
          .write(patch.copyWith(updatedAt: Value(DateTime.now())));

  Future<int> deleteById(int id) =>
      (delete(txTemplates)..where((t) => t.id.equals(id))).go();

  /// strftime('%s','now') is required because Drift stores DateTime as Unix
  /// epoch (INT). Passing toIso8601String() corrupts the column — see
  /// feedback_drift_customstatement_datetime memory.
  Future<void> markUsed(int id) async {
    await customStatement(
      "UPDATE tx_templates "
      "SET last_used_at = strftime('%s', 'now'), "
      "    updated_at = strftime('%s', 'now') "
      "WHERE id = ?",
      [id],
    );
  }

  /// Atomic reorder — caller passes ids in their new order.
  Future<void> reorder(List<int> idsInOrder) async {
    await db.transaction(() async {
      for (var i = 0; i < idsInOrder.length; i++) {
        await (update(txTemplates)..where((t) => t.id.equals(idsInOrder[i])))
            .write(TxTemplatesCompanion(sortOrder: Value(i * 10)));
      }
    });
  }
}
```

### 4.3 `TemplateRepository`

```dart
class TemplateRepository {
  TemplateRepository({required TemplatesDao dao}) : _dao = dao;
  final TemplatesDao _dao;

  Stream<List<TxTemplate>> watchAll() => _dao.watchAll();
  Stream<List<TxTemplate>> watchByLastUsed() => _dao.watchByLastUsed();

  Future<TxTemplate> create({
    required String name,
    required TxType type,
    int? amount,
    int? fromAccountId,
    int? toAccountId,
    int? categoryId,
    String? memo,
  }) async {
    final id = await _dao.insertOne(TxTemplatesCompanion.insert(
      name: name,
      type: type,
      amount: Value(amount),
      fromAccountId: Value(fromAccountId),
      toAccountId: Value(toAccountId),
      categoryId: Value(categoryId),
      memo: Value(memo),
    ));
    final row = await _dao.findById(id);
    if (row == null) throw StateError('inserted template not found id=$id');
    return row;
  }

  Future<void> update(int id, {
    String? name, TxType? type, int? amount, bool clearAmount = false,
    int? fromAccountId, bool clearFrom = false,
    int? toAccountId, bool clearTo = false,
    int? categoryId, bool clearCategory = false,
    String? memo,
  }) {
    return _dao.updateById(
      id,
      TxTemplatesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        type: type == null ? const Value.absent() : Value(type),
        amount: clearAmount
            ? const Value(null)
            : (amount == null ? const Value.absent() : Value(amount)),
        fromAccountId: clearFrom
            ? const Value(null)
            : (fromAccountId == null
                ? const Value.absent()
                : Value(fromAccountId)),
        toAccountId: clearTo
            ? const Value(null)
            : (toAccountId == null
                ? const Value.absent()
                : Value(toAccountId)),
        categoryId: clearCategory
            ? const Value(null)
            : (categoryId == null
                ? const Value.absent()
                : Value(categoryId)),
        memo: memo == null ? const Value.absent() : Value(memo),
      ),
    );
  }

  Future<void> delete(int id) => _dao.deleteById(id);
  Future<void> reorder(List<int> idsInOrder) => _dao.reorder(idsInOrder);
  Future<void> markUsed(int id) => _dao.markUsed(id);
}
```

### 4.4 `AnalyticsRepository.dailyExpenseMap` (확장)

```dart
/// Sum of expense amount per day for [month].
/// Returns Map<midnight_date, sum>. Days with 0 total are NOT included.
Future<Map<DateTime, int>> dailyExpenseMap({required DateTime month}) async {
  final start = DateTime(month.year, month.month);
  final end = DateTime(month.year, month.month + 1);
  final rows = await (_db.select(_db.transactions)
        ..where((t) =>
            t.deletedAt.isNull() &
            t.type.equalsValue(TxType.expense) &
            t.occurredAt.isBiggerOrEqualValue(start) &
            t.occurredAt.isSmallerThanValue(end)))
      .get();

  final map = <DateTime, int>{};
  for (final tx in rows) {
    final day = DateTime(
        tx.occurredAt.year, tx.occurredAt.month, tx.occurredAt.day);
    map[day] = (map[day] ?? 0) + tx.amount;
  }
  return map;
}
```

**Performance budget**: 10K 거래 가정 시 월 ~300건. 인덱스 (occurred_at DESC, deleted_at) 활용. 조회 + 집계 ≤ 200ms.

### 4.5 `AnalyticsRepository.categoryDonut` rollup (변경)

**M2 동작**: leaf 카테고리별 합계 → "점심값" 따로, "저녁값" 따로 (소분류가 있으면 도너츠 분산).

**M3 변경**: leaf의 `parent_category_id`를 따라 부모로 rollup. parent NULL이면 자기 자신이 대분류.

```dart
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

  // M3: rollup by parent. parent NULL → self가 대분류.
  // parent ID로 그룹핑하기 위해 categories를 한 번 더 조회해서 parent name도 가져옴.
  final allCats = await _db.select(_db.categories).get();
  final byId = {for (final c in allCats) c.id: c};

  final byParent = <int, _Aggregator>{};
  for (final row in rows) {
    final t = row.readTable(tx);
    final c = row.readTable(cat);
    // parent_category_id가 있으면 그 부모로 rollup, 없으면 자기 자신
    final parentId = c.parentCategoryId ?? c.id;
    final parent = byId[parentId] ?? c;
    byParent
        .putIfAbsent(parentId, () => _Aggregator(parent.id, parent.name, parent.isFixed))
        .add(t.amount);
  }
  return byParent.values
      .map((a) => CategorySegment(
            categoryId: a.id,
            categoryName: a.name,
            isFixed: a.isFixed,
            totalAmount: a.total,
          ))
      .toList()
    ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
}
```

### 4.6 `CategoryRepository` hierarchy 메서드 (확장)

```dart
class CategoryRepository {
  // 기존: listAll, findByName, upsertByName

  /// 대분류만 (parent NULL).
  Future<List<Category>> listTopLevel({CategoryKind? kind}) {
    final q = _db.select(_db.categories)
      ..where((c) => c.parentCategoryId.isNull());
    if (kind != null) q.where((c) => c.kind.equalsValue(kind));
    q.orderBy([
      (c) => OrderingTerm.asc(c.sortOrder),
      (c) => OrderingTerm.asc(c.name),
    ]);
    return q.get();
  }

  /// 특정 부모의 자식들.
  Future<List<Category>> listChildren(int parentId) {
    return (_db.select(_db.categories)
          ..where((c) => c.parentCategoryId.equals(parentId))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();
  }

  /// 부모 지정 (NULL 가능 — 대분류로 승격).
  Future<void> setParent(int id, int? parentId) async {
    if (parentId != null) {
      // 순환 방지: parentId의 카테고리가 이 id의 자식이면 거부
      final candidate = await _findById(parentId);
      if (candidate?.parentCategoryId == id) {
        throw StateError('순환 참조 방지: $parentId는 $id의 자식임');
      }
    }
    await (_db.update(_db.categories)..where((c) => c.id.equals(id)))
        .write(CategoriesCompanion(parentCategoryId: Value(parentId)));
  }

  Future<void> reorder(List<int> idsInOrder) async {
    await _db.transaction(() async {
      for (var i = 0; i < idsInOrder.length; i++) {
        await (_db.update(_db.categories)
              ..where((c) => c.id.equals(idsInOrder[i])))
            .write(CategoriesCompanion(sortOrder: Value(i * 10)));
      }
    });
  }

  Future<Category?> _findById(int id) =>
      (_db.select(_db.categories)..where((c) => c.id.equals(id)))
          .getSingleOrNull();
}
```

### 4.7 InputForm 확장 (`applyTemplate`)

```dart
class InputFormState {
  // ... 기존 필드
  final int? appliedTemplateId; // M3: track for markUsed on save

  InputFormState copyWith({
    // ...
    int? appliedTemplateId,
    bool clearTemplateId = false,
  }) => InputFormState(
    // ...
    appliedTemplateId: clearTemplateId ? null : (appliedTemplateId ?? this.appliedTemplateId),
  );
}

class InputFormNotifier extends Notifier<InputFormState> {
  void applyTemplate(TxTemplate t) {
    setType(t.type);
    if (t.amount != null) setAmount(t.amount!);
    setFromAccount(t.fromAccountId);
    setToAccount(t.toAccountId);
    setCategory(t.categoryId);
    setMemo(t.memo ?? '');
    state = state.copyWith(appliedTemplateId: t.id);
    // occurredAt remains today (default at form open)
  }
}
```

InputScreen 저장 흐름:
```dart
Future<void> _submit() async {
  // ... existing add path
  await repo.add(draft);
  // M3: mark template as used if applied
  final templateId = ref.read(inputFormProvider).appliedTemplateId;
  if (templateId != null) {
    await ref.read(templateRepositoryProvider).markUsed(templateId);
  }
  // ... reset
}
```

---

## 5. UI Specifications

### 5.1 `DailyCalendar` 위젯

```
┌───────────────────────────────────────────────┐
│  Sun  Mon  Tue  Wed  Thu  Fri  Sat            │  요일 헤더 (회색)
├───────────────────────────────────────────────┤
│   ·    ·    ·    1    2    3    4              │  prev-month padding (옅게)
│  12k    8k    ·   25k   ·    ·    ·             │  ※ heatmap 색 농도 = 그달 max 대비
│   5    6    7    8    9   10   11              │
│  ·   18k    ·    ·    ·    ·    ·              │
│  12   13   14   15   16   17   18              │
│  ·   45k    ·    ·    ·    ·    ·              │  ← max 강도 cell (alpha 0.85)
│  19   20   21   22   23   24   25              │
│  ·    ·    ·    ·    ·    ·    ·              │
│  26   27   28   29   30   ·    ·               │  next-month padding (옅게)
└───────────────────────────────────────────────┘
```

#### 셀 디자인

```
┌──────┐
│ 15  │  날짜 숫자 (top-left, labelMedium, onSurface)
│      │
│ 25k  │  amount (center bottom, bodySmall bold, primary)
└──────┘
배경: primary (heatmap alpha)
모서리: 12px rounded
크기: 가용폭 / 7 (각 셀 정사각형)
간격: 4px between cells
```

#### Heatmap 알고리즘

```dart
final maxAmount = dailyMap.values.fold<int>(0, max);
double alphaFor(int amount) {
  if (amount == 0) return 0;
  if (maxAmount == 0) return 0;
  final ratio = amount / maxAmount; // 0..1
  return (0.05 + ratio * 0.65).clamp(0.05, 0.7);
}
// 셀 배경색 = primary.withValues(alpha: alphaFor(amount))
```

**효과**: 0원 셀 = 투명 / 작은 지출 = 옅은 핑크 / 그달 최대 = 진한 핑크 (0.7).

#### 셀 탭 동작

```dart
onCellTap(DateTime day) async {
  // 1. 검색 필터에 단일 일자 범위 설정
  ref.read(searchFilterProvider.notifier).setDateRange(
    DateRange(
      from: day,
      to: day.add(const Duration(days: 1)),
      label: '${day.month}월 ${day.day}일',
    ),
  );
  // 2. 분석 → 내역 탭으로 자동 전환 (StatefulShellRoute branch index 1)
  context.go('/list');
}
```

`context.go('/list')`는 GoRouter가 이미 shell 안에서 branch 1로 자동 전환. 따로 `goBranch(1)` 부르지 않아도 됨.

#### Empty state

해당 달의 expense가 0건이면:
- 그리드 자체는 표시 (날짜 숫자만, amount 텍스트 없음)
- 하단에 "이 달에는 지출이 없습니다" subtle 텍스트

### 5.2 `AnalyticsScreen` 통합 (M3)

```
┌────────────────────────────────────────────┐
│  분석                                       │  AppBar
├────────────────────────────────────────────┤
│  ◀ 2026년 4월 ▶                            │  월 picker (공유)
│                                            │
│  📅 일별 지출                              │  Section title
│  ┌──────────────────────────────────────┐  │
│  │  S  M  T  W  T  F  S                  │  │
│  │  · ·  ·  1  2  3  4                   │  │
│  │  ...                                  │  │  DailyCalendar
│  └──────────────────────────────────────┘  │
│                                            │
│  📊 카테고리 비중                          │
│  ┌──────────────────────────────────────┐  │
│  │   [도너츠]                            │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  📈 고정비 vs 변동비                       │
│  ┌──────────────────────────────────────┐  │
│  │   [라인 차트]                         │  │
│  └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
```

월 picker가 3 위젯 모두 reactive하게 갱신.

### 5.3 `TemplatesScreen` (설정 sub)

```
┌────────────────────────────────────────────┐
│  ←  거래 템플릿                            │  AppBar (back)
├────────────────────────────────────────────┤
│                                            │
│  ≡  📤 월세                                │  drag handle + 이름
│      지출 · ₩650,000 · 신한 → 임대인       │  type · amount · accounts
│      메모: 월세 자동이체                   │
│                                            │
│  ≡  📤 통신비                              │
│      지출 · ₩(자동) · 신한 → SK텔레콤      │  amount NULL = "(자동)"
│      메모: 통신요금                        │
│                                            │
│  ≡  📥 급여                                │
│      수입 · ₩2,500,000 · → 신한 · 급여     │
│                                            │
│  ...                                       │
│                                            │
│                                  [+ 추가]  │  FAB
└────────────────────────────────────────────┘
```

- ReorderableListView로 drag-to-reorder. drop 시 `repo.reorder(idsInOrder)`
- Tap → TemplateFormSheet (edit)
- Long press → 삭제 (confirm dialog)
- FAB → TemplateFormSheet (new)
- Empty state: "템플릿이 없습니다. 자주 쓰는 거래를 저장해두세요"

### 5.4 `TemplateFormSheet`

AccountFormSheet 패턴 그대로:
```
┌──────────────────────────────┐
│  ───                          │  drag handle
│  거래 템플릿 추가/수정         │  title
│                              │
│  이름                         │
│  [월세                       ] │  text field (unique 검증)
│                              │
│  유형                         │
│  [지출][수입][이체][평가]      │  ChoiceChip wrap
│                              │
│  금액 (선택)                  │
│  [₩  650,000]                │  ← NULL 가능. hint = "사용 시 입력"
│                              │
│  보내는 계좌  [신한 ▾]         │  type-conditional
│  받는 계좌    [임대인 ▾]       │
│  카테고리     [월세/관리비 ▾]  │  type-conditional
│  메모         [월세 자동이체 ] │
│                              │
│             [저장]            │
└──────────────────────────────┘
```

- amount 필드: nullable. 사용자가 비우면 NULL로 저장 (InputScreen에서 비어 보임)
- name: unique 검증. 중복이면 "이미 같은 이름이 있습니다" 에러
- type 변경 시 stale 필드 clear (AccountFormSheet 패턴)

### 5.5 `TemplatePickerSheet`

```
┌──────────────────────────────┐
│  ───                          │  drag handle
│  템플릿 선택                  │  title
│                              │
│  📤 월세                     │  ListTile-ish
│  지출 · ₩650,000              │  subtitle
│                              │
│  📤 통신비                   │
│  지출 · ₩(자동)              │
│                              │
│  📤 구독료                   │
│  지출 · ₩14,900              │
│                              │
│  ─────────────────           │
│  + 새 템플릿 만들기 →        │  → TemplatesScreen으로 이동
└──────────────────────────────┘
```

- `templatesByLastUsedProvider` watch → lastUsedAt desc 정렬
- Tap → `inputFormProvider.notifier.applyTemplate(t)` + Navigator.pop
- "+ 새 템플릿 만들기" → `context.push('/settings/templates')` (BottomSheet 닫고)
- Empty state: "저장된 템플릿이 없습니다" + "+ 새 템플릿 만들기" 버튼

### 5.6 `InputScreen` 통합

기존 InputScreen 위에 1줄 추가:

```
┌──────────────────────────────┐
│  ✕  거래 추가                │
├──────────────────────────────┤
│                              │
│       ┌───────────────────┐  │
│       │ 📋 템플릿에서      │  │  ← M3 신규 버튼 (OutlinedButton)
│       └───────────────────┘  │
│                              │
│  [지출][수입][이체][평가]      │  type
│                              │
│  ₩  [25,000           ]      │  amount (커서 forced focus)
│                              │
│  ... (기존 필드들)            │
│                              │
│             [저장]            │
└──────────────────────────────┘
```

- 버튼 위치: type selector 위 (가장 먼저 시야)
- 버튼 크기: small/compact (메인 작업 흐름 방해 X)
- 버튼 onPressed → `showModalBottomSheet(builder: (_) => TemplatePickerSheet())`
- 선택 후 → 폼 prefill + amount focus 자동 (사용자가 amount 변경하기 쉽게)

### 5.7 `SettingsScreen` entries

기존 설정 항목 사이에 2개 추가 (템플릿 + 카테고리):

```
계정
  Google 로그인 ...

데이터 관리                     ← M3 신규 섹션
  📋 거래 템플릿 관리      →    ← Tap → /settings/templates push
  🏷️  카테고리 관리       →    ← Tap → /settings/categories push

동기화
  ...
```

ListTile + trailing chevron 패턴.

### 5.8 `CategoryPicker` 위젯 (cascading 2-step)

InputScreen·TemplateFormSheet·FilterChip의 카테고리 선택 UI를 통일.

```
┌──────────────────────────────────────┐
│  카테고리                             │  Section title
│                                      │
│  대분류                               │
│  [식비✓][교통][쇼핑][여가][의료]...   │  ChoiceChip 1줄 (대분류 list)
│                                      │
│  소분류 (식비)                        │  ← 대분류 선택 시 노출
│  [(식비 자체)][점심][저녁][카페]...   │  소분류 chip + "(대분류 자체)" 옵션
└──────────────────────────────────────┘
```

- 1단: 대분류 ChoiceChip wrap. selected = primary fill
- 2단: 선택된 대분류의 children. children이 있을 때만 노출. 없으면 "(소분류 없음)" 단일 옵션
- "(대분류 자체)" 옵션: 사용자가 대분류만으로 카테고리 지정 (예: 식비 일반)
- 결과 = 단일 categoryId (소분류 또는 대분류 leaf)

```dart
class CategoryPicker extends ConsumerWidget {
  const CategoryPicker({
    required this.kind,           // expense or income
    required this.selectedId,
    required this.onChanged,
  });
  final CategoryKind kind;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(...) {
    final topAsync = ref.watch(topLevelCategoriesProvider(kind));
    final selected = ref.watch(_resolvedCategoryProvider(selectedId));
    final parentId = selected.parentCategoryId ?? selected.id;
    final childrenAsync = ref.watch(categoryChildrenProvider(parentId));
    // ... render top-row chips + child-row chips
  }
}
```

### 5.9 `CategoriesScreen` (설정 sub)

```
┌────────────────────────────────────────────┐
│  ←  카테고리 관리                           │  AppBar
├────────────────────────────────────────────┤
│  지출                                       │  kind tab (expense/income)
│  [지출][수입]                                │
│                                            │
│  ▾ 식비                  ≡                 │  대분류 expand/collapse + drag handle
│      점심                                   │  소분류
│      저녁                                   │
│      카페                                   │
│  ▾ 교통                  ≡                 │
│      대중교통                               │
│      택시                                   │
│      주유                                   │
│  ▸ 쇼핑                  ≡                 │  collapsed
│  ▸ 여가                  ≡                 │
│  ...                                        │
│                                            │
│                                  [+ 추가]   │  FAB → CategoryFormSheet (new)
└────────────────────────────────────────────┘
```

- ExpansionTile per 대분류 + 자식 list
- 대분류 drag-reorder (sortOrder 변경)
- 자식도 drag-reorder (대분류 내에서)
- 대분류 long press → 삭제 confirm (자식이 있으면 자식이 대분류로 승격 = ON DELETE SET NULL)
- 자식 long press → 삭제 confirm
- Tap → CategoryFormSheet (edit)
- FAB → CategoryFormSheet (new) — kind 자동 (현재 탭의 kind)

### 5.10 `CategoryFormSheet`

```
┌──────────────────────────────┐
│  ───                          │
│  카테고리 추가/수정           │
│                              │
│  이름                         │
│  [점심                       ] │
│                              │
│  유형  [지출][수입]            │  ChoiceChip
│                              │
│  부모 카테고리 (선택)         │
│  [식비 ▾]                    │  Dropdown — kind=같은 type의 대분류만
│                              │  NULL 가능 = 대분류로 등록
│                              │
│  고정비 [○]                   │  Switch (M2 isFixed)
│                              │
│             [저장]            │
└──────────────────────────────┘
```

- 부모 카테고리 dropdown: kind=현재 type의 parent NULL인 카테고리만 (= 대분류)
- 자기 자신은 제외 (수정 모드)
- 부모 변경 후 isFixed는 유지 (각 카테고리 독립)

### 5.11 `InputScreen` + `FilterChip` 카테고리 chip 교체

기존 카테고리 chip Wrap 부분을 `CategoryPicker`로 교체. UX는 동일하지만 cascading 2-step 패턴 적용.

---

## 6. State Management (M3 신규 Provider)

| Provider | Type | 책임 |
|----------|------|------|
| `templatesDaoProvider` | `Provider<TemplatesDao>` | DI |
| `templateRepositoryProvider` | `Provider<TemplateRepository>` | DI |
| `templatesListProvider` | `StreamProvider<List<TxTemplate>>` | sortOrder asc — TemplatesScreen 용 |
| `templatesByLastUsedProvider` | `StreamProvider<List<TxTemplate>>` | lastUsedAt desc — TemplatePickerSheet 용 |
| `dailyExpenseMapProvider` | `FutureProvider.family<Map<DateTime,int>, DateTime>` | DailyCalendar 용 |
| **`topLevelCategoriesProvider`** | `FutureProvider.family<List<Category>, CategoryKind>` | 대분류만 조회 — CategoryPicker 1단 |
| **`categoryChildrenProvider`** | `FutureProvider.family<List<Category>, int>` | 특정 부모의 자식 — CategoryPicker 2단 |
| **`categoriesByKindProvider`** | `FutureProvider.family<List<Category>, CategoryKind>` | CategoryFormSheet 부모 dropdown 용 |

InputFormState에 `appliedTemplateId` 필드 추가 (위 §4.7 참고).

---

## 7. Test Plan

### 7.1 Unit Tests (M3 신규)

- `AnalyticsRepository.dailyExpenseMap` (in-memory Drift):
  - 빈 달 → 빈 Map
  - 단일 날짜 1건 → {day: amount}
  - 같은 날짜 여러 건 → sum
  - 월 경계 — 이전/다음달 거래 포함 안됨
  - expense 외 type (income/transfer/valuation) 제외
  - deletedAt 거래 제외
- `AnalyticsRepository.categoryDonut` rollup (in-memory Drift):
  - 모든 leaf가 대분류 (parent NULL) — 기존 동작과 동일
  - 소분류가 있으면 부모로 합산 (예: 점심 5,000 + 저녁 8,000 → 식비 13,000)
- `CategoryRepository.setParent` 순환 방지:
  - A → B → A 시도 시 StateError 발생

### 7.2 Integration Tests (M3.5 세션)

`test/integration/template_repository_test.dart` (4건):
- create → tx_templates에 row insert + 생성 timestamp 자동
- update → 변경 + updatedAt 갱신
- markUsed → lastUsedAt = now (strftime epoch)
- delete → row 제거

`test/integration/category_hierarchy_test.dart` (4건):
- listTopLevel(expense) → parent NULL인 expense 카테고리만 반환
- listChildren(parentId) → 해당 부모의 자식들만 반환
- setParent(id, parentId) → 정상 적용 + DB 반영
- ON DELETE SET NULL → 부모 삭제 시 자식의 parent_category_id가 NULL로 (자식 = 대분류로 승격)

### 7.3 Migration Tests

- v3 → v4 in-memory test: v3 schema로 시작 → v4 마이그레이션 → tx_templates 테이블 존재 + categories.parent_category_id 컬럼 존재 + 기존 17 카테고리 모두 parent_category_id = NULL + 기존 데이터 보존

### 7.4 Manual Verification (M3 DoD)

- [ ] M2 데이터 보존 — 디바이스에서 v4 마이그레이션 실행 후 거래/계좌/카테고리 모두 표시
- [ ] 템플릿 생성 → 사용 → lastUsedAt 갱신 → picker에서 위로 정렬
- [ ] 분석 탭 진입 → 달력 표시 → heatmap 색 농도 정확
- [ ] 달력 셀 탭 → 내역 탭 자동 전환 + 그 날짜 거래만 필터됨
- [ ] 템플릿 amount NULL → InputScreen에서 amount 빈 칸
- [ ] Sheets templates 시트 자동 생성 + 템플릿 동기화
- [ ] APK 크기 ≤ 32MB

---

## 8. Sync Impact

### 8.1 templates 시트 신규

```
sheet name: templates
columns:    name | type | amount | from_account | to_account | category | memo | sort_order | last_used_at
range:      templates!A1:I
sync mode:  overwrite snapshot (accounts/monthly_summary 패턴 동일)
```

`SyncService.flush` 흐름:
1. transactions queue drain (변경 없음)
2. accounts snapshot push (변경 없음)
3. monthly_summary aggregate push (변경 없음)
4. **templates snapshot push** (신규)

```dart
// sync_service.dart
Future<SyncFlushResult> flush() async {
  // ... existing tx queue drain
  // ... accounts snapshot
  var templatesSynced = false;
  try {
    await _pushTemplatesSnapshot(spreadsheetId);
    await _writeKv(_lastTemplatesSyncAtKey, DateTime.now().toIso8601String());
    templatesSynced = true;
  } catch (_) {/* partial OK */}
  // ... monthly_summary
  return SyncFlushResult(
    // ...
    templatesSynced: templatesSynced,
  );
}

Future<void> _pushTemplatesSnapshot(String spreadsheetId) async {
  final all = await _templatesDao.readAll();
  final accounts = await _accountsDao.readAll();
  final accountNameById = {for (final a in accounts) a.id: a.name};
  final categories = await _db.select(_db.categories).get();
  final categoryNameById = {for (final c in categories) c.id: c.name};

  final values = <List<Object?>>[
    SheetLayout.templatesHeader,
    ...all.map((t) => _templateToRow(t, accountNameById, categoryNameById)),
  ];
  await _sheets.overwriteRange(
    spreadsheetId,
    SheetLayout.templatesOverwriteRange,
    values,
  );
}

List<Object?> _templateToRow(
  TxTemplate t,
  Map<int, String> accountNameById,
  Map<int, String> categoryNameById,
) => [
  t.name,
  t.type.name,
  t.amount ?? '',
  t.fromAccountId == null ? '' : (accountNameById[t.fromAccountId!] ?? ''),
  t.toAccountId == null ? '' : (accountNameById[t.toAccountId!] ?? ''),
  t.categoryId == null ? '' : (categoryNameById[t.categoryId!] ?? ''),
  t.memo ?? '',
  t.sortOrder,
  t.lastUsedAt?.toIso8601String() ?? '',
];
```

`_ensureSpreadsheet`에 templates 시트 ensure 추가:
```dart
await _sheets.ensureSheet(
  id, SheetLayout.templatesSheet, SheetLayout.templatesHeader);
```

### 8.2 SyncFlushResult 확장

```dart
class SyncFlushResult {
  // ... 기존 필드
  final bool templatesSynced;
  // ...
}
```

### 8.3 양방향 동기화는 M4

M3는 **device → sheet** push only (M2 패턴과 일관). 디바이스 간 양방향은 M4에서 검토 (필요시).

---

## 9. Performance & Security

| 영역 | 목표 | 전략 |
|------|------|------|
| 달력 진입 | ≤ 400ms (10K 거래) | dailyExpenseMap 인덱스(occurred_at) 활용 + Map 결과 30 entries 이하 + Riverpod cache |
| 템플릿 picker 표시 | ≤ 100ms (50개 템플릿) | watchByLastUsed Stream + 메모리 정렬 |
| 마이그레이션 시간 | ≤ 1s (1만 행 가정) | createTable은 metadata-only |
| APK 증가 | ≤ +2MB | 신규 의존성 0 |
| 보안 | 변경 없음 | M2 정책 유지 |

---

## 10. Risks (Plan §7과 동기화)

| Risk | Design 대응 |
|------|-------------|
| Drift v3→v4 마이그레이션 데이터 손실 | `createTable`만 사용. v3→v4 in-memory 테스트 사전 검증. M2 v2→v3 패턴 그대로 |
| 템플릿 amount NULL 처리 | UI에서 amount 비워둠. InputForm은 사용자가 입력하면 NewTransaction.validate 통과. 입력 안 하면 저장 시 amount=0 → validate 실패 (안전) |
| Sheets templates 시트 기존 사용자 호환 | `ensureSheet`이 시트+헤더 자동 생성. 기존 3 시트 영향 없음 |
| 달력 month picker state 공유 | AnalyticsScreen이 `_selectedMonth` state 보유. 달력에 prop으로 전달 (down). family provider로 캐싱 |
| 달력 셀 탭 → 내역 전환 | `context.go('/list')` + searchFilterProvider 한 번에 처리. ListScreen은 filter 변경 reactive |
| 템플릿 외부 FK가 stale (계좌·카테고리 삭제됨) | `isResolvableWith` extension으로 사용 시점 검증. UI에서 invalid 표시. NULL이면 폼에 빈값 prefill |
| 템플릿 사용 후 lastUsedAt 갱신 타이밍 | InputScreen save 성공 시점에만 `markUsed` 호출. 취소·실패면 갱신 안 함 |

---

## 11. Implementation Guide

### 11.1 의존성 추가 (pubspec.yaml)

```yaml
# 변경 없음 — M2 의존성 그대로
# fl_chart, drift, sqlite3 (dev), Pretendard/SUIT 모두 유지
```

신규 의존성 0건. APK 사이즈 영향 거의 없음.

### 11.2 구현 순서 (의존 DAG)

```
1. tables.dart + Drift v4 마이그레이션 + tx_templates                 (M3.1)
2. TemplatesDao + TemplateRepository                                  (M3.1)
3. providers.dart — templates DI 추가                                 (M3.1)
4. TemplateFormSheet (생성/수정 BottomSheet)                          (M3.2)
5. TemplatesScreen (목록 + reorder + FAB)                             (M3.2)
6. router.dart — /settings/templates push sub-route                   (M3.2)
7. SettingsScreen — entry 추가                                        (M3.2)
8. TemplatePickerSheet                                                (M3.2)
9. InputFormState — appliedTemplateId 필드 + applyTemplate            (M3.2)
10. InputScreen — "📋 템플릿에서" 버튼 + markUsed 호출                (M3.2)
11. AnalyticsRepository.dailyExpenseMap                               (M3.3)
12. DailyCalendar 위젯                                                (M3.3)
13. AnalyticsScreen — 달력 통합 + month picker 공유                    (M3.3)
14. SheetLayout — templates sheet/header                              (M3.4)
15. SyncService._pushTemplatesSnapshot + ensureSheet 추가              (M3.4)
16. sheet_layout_test 보강                                            (M3.4)
17. TemplateRepository 통합 테스트 4건                                (M3.4)
18. dailyExpenseMap 단위 테스트 6건                                   (M3.4)
19. APK 빌드 검증 + 디바이스 실증                                     (M3.4)
```

### 11.3 Session Guide (Module Map)

| Session | Scope Key | 포함 | 예상 LOC |
|---------|-----------|------|---------:|
| **session-1** | `schema` | Drift v4 + tables.dart (txTemplates 테이블 + categories.parentCategoryId 컬럼) + v3_to_v4.dart + TemplatesDao + TemplateRepository + CategoryRepository hierarchy 메서드 + providers DI | ~350 |
| **session-2** | `template-mgmt` | TemplateFormSheet + TemplatesScreen + /settings/templates push + SettingsScreen entry + TemplatePickerSheet + InputFormState 확장 + InputScreen 버튼 + markUsed 호출 | ~450 |
| **session-3** | `categories-ui` | CategoryPicker 위젯 + CategoryFormSheet + CategoriesScreen + /settings/categories push + InputScreen·TemplateForm·FilterChip 카테고리 chip swap + 분석 도너츠 rollup 변경 | ~500 |
| **session-4** | `calendar` | dailyExpenseMap + DailyCalendar 위젯 + AnalyticsScreen 통합 + 셀 탭 → 내역 전환 | ~300 |
| **session-5** | `sync-tests` | SheetLayout templates + tx 10컬럼 + SyncService _pushTemplatesSnapshot + _txToRow parentName + sheet_layout_test 보강 + 통합 테스트 8건 + 단위 테스트 8건 + APK 검증 | ~250 |

**총 ~1,850 LOC** (Plan 1.1 추정과 일치).

### 11.4 검증 명령어 (M3 DoD)

```bash
flutter pub get
dart run build_runner build --force-jit --delete-conflicting-outputs
flutter analyze        # 0 issues
flutter test           # M1 63 + M2 ~13 + M3 ~14 = ~90
flutter test test/integration/  # 통합 테스트만
flutter build apk --release --analyze-size  # ≤ 32MB
```

---

## 12. Open Questions

| # | Question | Owner | Resolve By |
|---|----------|-------|-----------|
| Q1 | 템플릿 사용 시 입력 화면에 "이 거래는 템플릿에서 채워졌습니다" 시각 hint 표시? | 본인 (구현 후) | M3.2 |
| Q2 | 달력 그리드 첫 요일 — 일요일(미국식) vs 월요일(한국 캘린더 관습)? | 본인 | M3.3 시작 전 |
| Q3 | 템플릿 시트 → 디바이스 pull (양방향) 기능 | 본인 (사용 후) | M4 검토 |
| Q4 | 달력 셀에 income도 표시하는 토글 추가 | 본인 (사용 후) | M4 또는 보류 |
| Q5 | 템플릿 카테고리 그룹핑 (5+ 템플릿 시) | 본인 (5개 넘었을 때) | M4 |

---

## 13. Decision Record (Plan + Design)

| 결정 | 선택 | 근거 |
|------|------|------|
| Architecture | Option C (Pragmatic) | M2 철학 동일 — 새 도메인은 새 모듈, 같은 책임은 기존 모듈 흡수 |
| 달력 위치 | 분석 탭 통합 | 월 picker 공유, 4탭 유지, reference 톤 |
| 달력 expense 정의 | expense type만 | M2 분석 차트와 일관. 카드 결제 transfer 제외 |
| 달력 셀 표시 | 텍스트 + heatmap | 정량 + 직관 |
| 템플릿 관리 위치 | 설정 sub-screen | 4탭 유지 + 사용은 InputScreen picker로 충분 |
| 템플릿 amount | nullable | 변동 가능 (전기/통신). 사용자가 사용 시점에 입력 |
| 템플릿 정렬 | sortOrder + lastUsedAt | 수동 컨트롤 + 자주 쓰는 것 자동 우선 |
| 템플릿 occurredAt 기본 | 오늘 | 가장 자연스러운 기본값 |
| Sheets sync | one-way push (device → sheet) | M2 패턴 일관. 양방향은 M4 |
| Migration 명명 | `v{n}_to_{m}.dart` | M2 표준 유지 |
| Heatmap 알고리즘 | `(amount/max).clamp(0.05, 0.7)` | 0인 셀은 투명, 그달 max는 0.7 alpha (텍스트 가독성 보존) |
| **카테고리 hierarchy** | 2-level (대분류/소분류만) | 3+ level은 UX 복잡도 ↑↑. 가계부 도메인에 2-level이면 충분 |
| **카테고리 시드** | 기존 17개 모두 대분류 (parent NULL) | 마이그레이션 데이터 100% 호환. 사용자가 관리 화면에서 소분류 추가 |
| **카테고리 관리 위치** | 설정 sub-screen | 템플릿과 동일 패턴 — 일관성 |
| **카테고리 picker 패턴** | cascading 2-step (대분류 chip → 소분류 chip) | InputForm·TemplateForm·FilterChip 공유. 단일 위젯 (CategoryPicker) |
| **분석 도너츠 집계** | leaf → parent rollup | 대분류 단위로 합산. M2 leaf 단위 도너츠는 작은 슬라이스 너무 많아짐 |
| **Sheets tx 카테고리 컬럼** | 2 컬럼 분리 (`category_parent` + `category`) | 시트에서 피봇·집계 시 부모 정보 필수. 단일 슬래시 컬럼은 lossy |
| **카테고리 자기참조 ON DELETE** | SET NULL | 대분류 삭제 시 자식이 대분류로 승격 (cascade는 데이터 손실 위험) |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-29 | Initial M3 design (Option C). 9 신규 + 7 수정 파일, ~1,200 LOC, 4 세션 분할. |
| 1.1 | 2026-04-29 | **Feature C 추가** — 카테고리 2-level 계층. categories.parent_category_id + CategoryPicker 위젯 + CategoriesScreen + 분석 도너츠 rollup + Sheets tx 10컬럼. 12 신규 + 9 수정, ~1,850 LOC, 5 세션. |
