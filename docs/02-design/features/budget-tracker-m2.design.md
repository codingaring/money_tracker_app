---
template: design
version: 1.0
feature: budget-tracker-m2
cycle: M2
date: 2026-04-28
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.3.0"
level: Dynamic
architecture: Option C — Pragmatic (analytics module + UI-only additions, migrations split)
basePlan: docs/01-plan/features/budget-tracker-m2.plan.md
baseDesign: docs/02-design/features/budget-tracker.design.md
---

# Budget Tracker — M2 Design Document

> **Architecture**: Pragmatic (M1과 동일 철학) — 새 도메인이 있는 부분은 모듈 신설, UI/검색은 기존 모듈에 흡수.
>
> **M1 → M2 핵심 변경**: 신규 `features/analytics/` 모듈 + Drift v2→v3 마이그레이션 + 6번째 탭(분석) + List SearchBar + 카드 상세 화면 + 계좌 트리 + Repository 통합 테스트 5건.

---

## Context Anchor (Plan Carry-Over)

| Key | Value |
|-----|-------|
| **WHY** | 누적된 데이터로 본인 소비 패턴 이해 + 카드 결제 예측 → 행동 결정 도움 |
| **WHO** | 본인 1인 (M1 사용자, 1-2주 데이터 누적된 상태) |
| **RISK** | 6탭 좁아짐 / 카드 결제일 부재 (스키마 v3) / 차트 학습 곡선 / 검색 성능 |
| **SUCCESS** | 카드 결제 예정 정확 / 카테고리 분석 매월 1회 사용 / 검색 ≤ 100ms / 통합 테스트 60% |
| **SCOPE** | 카드 상세 + 분석 탭 + 검색·필터 + 계좌 트리 + Repo 통합 테스트. 반복·리포트는 M3. |

---

## 1. Overview

### 1.1 변경 요약 (M1 → M2)

```
M1 = 입력 + 보관 (4-type Tx, 5탭, 3-시트 동기화)
M2 = 이해 + 예측 (분석 탭 + 카드 결제 예측 + 검색)
```

| 영역 | M1 | M2 추가 |
|------|------|---------|
| Schema | 5 테이블 (v2) | accounts.due_day 컬럼 (v3) |
| Modules | 8 (db, transactions, accounts, categories, sync, dashboard, settings, app) | + `features/analytics/` |
| 탭 | 5 (홈/입력/내역/계좌/설정) | + 분석 (6탭) |
| 화면 | 5개 | + 카드 상세 (계좌 탭 drill-down) + 분석 화면 |
| Drift 마이그레이션 | 없음 (v2 from scratch) | v2→v3 (첫 마이그레이션) |
| 차트 | 없음 | fl_chart (도너츠 + 라인) |
| 검색 | ListScreen 단순 reverse-chronological | SearchBar + 칩 필터 |
| 통합 테스트 | deferred | TransactionRepository 5건 (sqlite3 dev_dep) |

### 1.2 변경 없는 부분

| 영역 | 그대로 |
|------|--------|
| 회계 모델 | 4-type Tx + Accounts |
| 잔액 갱신 | atomic via AccountsDao |
| Sheets 동기화 | 3-시트 SyncService (시트 컬럼만 due_day 추가) |
| 상태관리 | Riverpod 2.x |
| 라우팅 | GoRouter (StatefulShellRoute, branch만 6번째 추가) |

---

## 2. Architecture

### 2.1 모듈 분할 (M2 추가분)

```
money_tracker_app/lib/
├── features/
│   ├── analytics/                              # 🆕 신규 모듈
│   │   ├── domain/
│   │   │   ├── category_segment.dart           # 도너츠 1조각
│   │   │   └── monthly_split_series.dart       # 라인 차트 1포인트
│   │   ├── data/
│   │   │   └── analytics_repository.dart       # 집계 쿼리
│   │   └── ui/
│   │       ├── analytics_screen.dart           # 메인 분석 화면 (월 선택 + 도너츠 + 라인)
│   │       ├── category_donut_chart.dart       # fl_chart PieChart wrapper
│   │       └── fixed_variable_line_chart.dart  # fl_chart LineChart wrapper
│   ├── accounts/
│   │   ├── domain/card_detail_metrics.dart     # 🆕 (UI domain 값 객체)
│   │   ├── data/
│   │   │   └── card_detail_repository.dart     # 🆕 카드 한정 집계
│   │   └── ui/
│   │       ├── accounts_screen.dart            # ✏️ 트리 표시 추가
│   │       ├── account_form_sheet.dart         # ✏️ due_day + 부모 dropdown 추가
│   │       └── card_detail_screen.dart         # 🆕 카드 상세
│   └── transactions/
│       ├── data/transactions_dao.dart          # ✏️ search() 메서드 추가
│       └── ui/
│           ├── list_screen.dart                # ✏️ SearchBar + 필터 칩 통합
│           ├── search_bar_widget.dart          # 🆕 SearchBar
│           └── filter_chips.dart               # 🆕 칩 필터
└── core/
    └── db/
        ├── tables.dart                         # ✏️ accounts.dueDay 컬럼
        ├── app_database.dart                   # ✏️ schemaVersion=3, onUpgrade
        └── migrations/                         # 🆕
            └── v2_to_v3.dart                   # add_column accounts.due_day
```

**신규 파일**: 11개 / **수정 파일**: 7개 / 예상 LOC: ~900

### 2.2 의존성 그래프 (변경분만)

```
            ┌────────────────────────┐
            │  UI (existing 5 +       │
            │  + AnalyticsScreen      │
            │  + CardDetailScreen)    │
            └─────────┬──────────────┘
                      │
       ┌──────────────┼──────────────┬──────────────┐
       ▼              ▼              ▼              ▼
┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐
│Analytics   │  │CardDetail  │  │Tx (search) │  │M1 existing │
│Repository  │  │Repository  │  │ via DAO    │  │repos       │
│ 🆕         │  │ 🆕 (UI)    │  │ ✏️         │  │            │
└─────┬──────┘  └─────┬──────┘  └──────┬─────┘  └────────────┘
      │               │                │
      └───────────────┴────────────────┘
                      │
                      ▼
              ┌──────────────┐
              │ AppDatabase  │
              │ (Drift v3)   │
              └──────────────┘
```

### 2.3 레이어 책임 (M2 추가)

| 레이어 | 신규 책임 |
|--------|----------|
| `analytics/data/` | 집계 SQL — 카테고리/고정/기간별 합계. **읽기 전용** |
| `accounts/data/card_detail_repository` | 카드 한정 metrics 조립 (기존 DAO read + 결제일 계산) |
| `transactions/data/transactions_dao.search()` | 키워드+필터 조합 단일 쿼리 |
| `core/db/migrations/v2_to_v3` | 1회성 schema upgrade (add_column) |

---

## 3. Data Model (Drift v3 Delta)

### 3.1 변경: `accounts` 테이블

| 컬럼 | Type | 변경 | 설명 |
|------|------|:----:|------|
| 기존 10 컬럼 | — | 유지 | id/name/type/balance/is_active/parent_account_id/note/sort_order/created_at/updated_at |
| **`due_day`** | INTEGER | **🆕 v3** | NULL 허용. credit_card 타입에만 의미 (1-31). UI에서 type 분기로 강제 |

### 3.2 마이그레이션 v2 → v3

```dart
// core/db/migrations/v2_to_v3.dart
import 'package:drift/drift.dart';
import '../app_database.dart';

class V2ToV3 {
  static Future<void> apply(Migrator m, AppDatabase db) async {
    await m.addColumn(db.accounts, db.accounts.dueDay);
  }
}
```

```dart
// app_database.dart 수정 부분
@override
int get schemaVersion => 3;

@override
MigrationStrategy get migration => MigrationStrategy(
      onCreate: (m) => m.createAll(),
      onUpgrade: (m, from, to) async {
        if (from < 3) await V2ToV3.apply(m, this);
      },
      beforeOpen: (_) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
```

**검증 패턴** (M2.1 세션):
1. M1 기반 디바이스 DB (v2)에 직접 fluttering 실행 → 마이그레이션 자동 trigger → due_day 컬럼 존재 확인 (`PRAGMA table_info(accounts)`)
2. 기존 거래/계좌 데이터 0손실 검증 (BalanceReconciler 통과 확인)

### 3.3 Sheets `accounts` 시트 컬럼 추가

| Before | After |
|--------|-------|
| name / type / balance / parent_account / is_active / updated_at (6 cols) | + `due_day` (7번째, A:G) |

`SheetLayout.accountsHeader`에 `'due_day'` 추가 + `accountsOverwriteRange` `A1:G`로 변경.

`SyncService._pushAccountsSnapshot`은 자동으로 새 컬럼 포함. 기존 사용자 시트는 첫 동기화 시 헤더가 자동 갱신됨 (`ensureSheet` 멱등 갱신).

---

## 4. Component Specifications

### 4.1 `AnalyticsRepository`

```dart
class CategorySegment {
  const CategorySegment({
    required this.categoryId,
    required this.categoryName,
    required this.isFixed,
    required this.totalAmount,
  });
  final int categoryId;
  final String categoryName;
  final bool isFixed;
  final int totalAmount;
}

class MonthlySplitSeries {
  const MonthlySplitSeries({
    required this.yearMonth,
    required this.fixedAmount,
    required this.variableAmount,
  });
  final String yearMonth;
  final int fixedAmount;
  final int variableAmount;
  int get totalExpense => fixedAmount + variableAmount;
}

class AnalyticsRepository {
  AnalyticsRepository(this._db);
  final AppDatabase _db;

  /// 월별 카테고리별 expense 합계 — 도너츠 차트 용.
  Future<List<CategorySegment>> categoryDonut({
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await (_db.select(_db.transactions).join([
      innerJoin(_db.categories,
          _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ])
      ..where(_db.transactions.deletedAt.isNull() &
          _db.transactions.type.equalsValue(TxType.expense) &
          _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
          _db.transactions.occurredAt.isSmallerThanValue(end)))
        .get();
    // Aggregate in Dart by category_id (small data set per month).
    final byCat = <int, _Aggregator>{};
    for (final row in rows) {
      final tx = row.readTable(_db.transactions);
      final cat = row.readTable(_db.categories);
      byCat
          .putIfAbsent(cat.id, () => _Aggregator(cat))
          .total += tx.amount;
    }
    return byCat.values
        .map((a) => CategorySegment(
              categoryId: a.cat.id,
              categoryName: a.cat.name,
              isFixed: a.cat.isFixed,
              totalAmount: a.total,
            ))
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
  }

  /// 최근 N개월 고정/변동 분리 시리즈 — 라인 차트 용.
  Future<List<MonthlySplitSeries>> fixedVariableSeries({
    required int months,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month - (months - 1));
    final rows = await (_db.select(_db.transactions).join([
      innerJoin(_db.categories,
          _db.categories.id.equalsExp(_db.transactions.categoryId)),
    ])
      ..where(_db.transactions.deletedAt.isNull() &
          _db.transactions.type.equalsValue(TxType.expense) &
          _db.transactions.occurredAt.isBiggerOrEqualValue(start)))
        .get();
    return _aggregateMonthly(rows, today, months);
  }
}
```

**Performance budget**: 10K 거래 가정 시 월 ~300건. 인덱스 `idx_tx_occurred_desc (deleted_at, occurred_at DESC)` 활용. 조회 + 집계 ≤ 200ms.

### 4.2 `CardDetailRepository`

```dart
class CardDetailMetrics {
  const CardDetailMetrics({
    required this.account,
    required this.currentMonthCharges,
    required this.nextDueDate,
    required this.daysUntilDue,
    required this.expectedPayment,
    required this.recentCharges,
  });
  final Account account;
  /// 이번 달 해당 카드로 발생한 expense 합계 (절댓값).
  final int currentMonthCharges;
  /// 다음 결제 예정일. due_day가 NULL이거나 type≠credit_card이면 NULL.
  final DateTime? nextDueDate;
  /// 오늘부터 nextDueDate까지 일수. NULL일 때 -1.
  final int daysUntilDue;
  /// 예상 결제액 = -account.balance (음수를 양수로). 양수면 과오결제.
  final int expectedPayment;
  /// 해당 카드 최근 사용 내역 10건 (오늘부터 과거).
  final List<TxRow> recentCharges;
}

class CardDetailRepository {
  CardDetailRepository({
    required AppDatabase db,
    required AccountsDao accountsDao,
    required TransactionsDao txDao,
  });

  Future<CardDetailMetrics> compute(int accountId, {DateTime? now}) async {
    final today = now ?? DateTime.now();
    final account = await _accountsDao.findById(accountId);
    if (account == null || account.type != AccountType.creditCard) {
      throw ArgumentError('not a credit card: $accountId');
    }
    // ... parallel queries ...
    final nextDue = computeNextDueDate(account.dueDay, today);
    return CardDetailMetrics(
      account: account,
      currentMonthCharges: thisMonthSum,
      nextDueDate: nextDue,
      daysUntilDue: nextDue == null
          ? -1
          : nextDue.difference(today).inDays,
      expectedPayment: account.balance < 0 ? -account.balance : 0,
      recentCharges: recent,
    );
  }

  /// Pure function — testable.
  static DateTime? computeNextDueDate(int? dueDay, DateTime today) {
    if (dueDay == null) return null;
    final clamped = dueDay.clamp(1, 28); // 안전: 2월은 28일까지
    var next = DateTime(today.year, today.month, clamped);
    if (next.isBefore(today)) {
      next = DateTime(today.year, today.month + 1, clamped);
    }
    return next;
  }
}
```

### 4.3 `TransactionsDao.search()` (확장)

```dart
Future<List<TxRow>> search({
  String? keyword,
  DateTime? from,
  DateTime? to,
  int? accountId,
  int? categoryId,
  TxType? type,
  int limit = 200,
}) {
  final q = select(transactions)
    ..where((t) => t.deletedAt.isNull());

  if (keyword != null && keyword.trim().isNotEmpty) {
    q.where((t) => t.memo.like('%${keyword.trim()}%'));
  }
  if (from != null) {
    q.where((t) => t.occurredAt.isBiggerOrEqualValue(from));
  }
  if (to != null) {
    q.where((t) => t.occurredAt.isSmallerThanValue(to));
  }
  if (accountId != null) {
    q.where((t) =>
        t.fromAccountId.equals(accountId) |
        t.toAccountId.equals(accountId));
  }
  if (categoryId != null) {
    q.where((t) => t.categoryId.equals(categoryId));
  }
  if (type != null) {
    q.where((t) => t.type.equalsValue(type));
  }

  q
    ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)])
    ..limit(limit);
  return q.get();
}
```

**Performance**: 인덱스 (occurred_at DESC, deleted_at) + memo LIKE는 키워드 입력 시만. 디바운스 250ms로 입력 중 N회 호출 방지.

---

## 5. UI Specifications

### 5.1 NavigationBar 6탭

```
홈 / 입력 / 내역 / 계좌 / 분석 / 설정
🏠   ➕    📋    🏦    📊    ⚙️
```

(M1의 5탭에 "분석" 5번째 위치 삽입. 설정은 6번째로 밀림.)

### 5.2 AnalyticsScreen

```
┌───────────────────────────────────────┐
│ ← 분석                                │
├───────────────────────────────────────┤
│ ◀ 2026-04 ▶                           │   월 선택기 (이전/다음)
│                                       │
│  [도너츠 차트]                        │
│  식비       45%   ₩540,000           │   상위 5개 + "기타"
│  교통       18%   ₩216,000           │
│  쇼핑       12%   ₩144,000           │
│  여가       10%   ₩120,000           │
│  의료        8%   ₩96,000            │
│  기타        7%   ₩84,000            │
│                                       │
├───────────────────────────────────────┤
│ 고정비 vs 변동비 (최근 6개월)         │
│                                       │
│  [라인 차트]                          │
│  ── 고정비 (월세/통신/구독/보험/이자) │
│  ── 변동비 (식비/교통/쇼핑/...)       │
│                                       │
│  11월: 고정 850k / 변동 1,200k       │
│  12월: 고정 850k / 변동 980k         │
│  1월:  고정 850k / 변동 1,100k       │
│  2월:  고정 850k / 변동 1,350k       │
│  3월:  고정 850k / 변동 1,150k       │
│  4월:  고정 850k / 변동 1,250k       │
└───────────────────────────────────────┘
```

- 월 선택기로 도너츠 데이터 변경 (state in screen)
- 라인 차트는 항상 최근 6개월 (현재 월 포함)
- 빈 데이터: "거래 없음" empty state
- 카테고리 6개 초과 시 상위 5 + "기타" (총합)

### 5.3 CardDetailScreen (계좌 탭 drill-down)

```
┌───────────────────────────────────────┐
│ ← 삼성카드                            │
├───────────────────────────────────────┤
│  💳 다음 결제                         │
│   D-12 (5월 10일)                     │
│   예상 ₩ 1,352,500                   │
├───────────────────────────────────────┤
│  이번 달 사용                         │
│   ₩ 850,000                          │
│   ━━━━━━━━━━━━━━━━━━━━━ 63%       │   바 그래프 (예상 결제액 대비)
├───────────────────────────────────────┤
│  최근 사용                            │
│  ─────────────                        │
│  04-28  식비  -12,000  점심          │
│  04-27  교통  -1,250   버스          │
│  04-26  쇼핑  -45,000  의류          │
│  04-25  식비  -8,000   카페          │
│  ... (최대 10건)                     │
│                                       │
│  [전체 내역 보기 →]                   │   List 탭 (이 카드 필터)로 이동
└───────────────────────────────────────┘
```

- D-day 음수면 "오늘 결제일" / 양수면 "D-N (날짜)"
- due_day NULL이면 "결제일 미설정 — 계좌 수정에서 추가"
- "전체 내역 보기" → `context.go('/list')` + 검색 상태에 accountId 미리 set

### 5.4 ListScreen + SearchBar

```
┌───────────────────────────────────────┐
│ 거래 내역                             │
├───────────────────────────────────────┤
│ 🔍 [메모 검색...                  ✕]│   SearchBar (debounce 250ms)
│                                       │
│ [전체기간▾] [전체계좌▾] [전체타입▾]│   필터 칩 (선택 시 highlight)
├───────────────────────────────────────┤
│ 결과 X건                              │
│                                       │
│ 2026-04-28 (월)                       │
│ 식비       -12,000  신한      ⏳     │
│ ...                                   │
└───────────────────────────────────────┘
```

- 키워드 검색은 memo만 (단순)
- 칩 탭 → BottomSheet으로 옵션 선택 (전체기간 / 이번달 / 지난달 / 직접지정 / etc.)
- 필터 모두 clear → 기존 watchAll() reactive 스트림으로 복귀

### 5.5 AccountsScreen + 트리

**M1 (평면)** → **M2 (트리)**:
```
M1                          M2
─────────────              ──────────────
현금성                     현금성
• 신한 주거래              ▸ 신한 주거래         4,200,000
                              ├ 삼성카드      -1,352,500
                              └ 현대카드        -50,000
부채 — 신용카드            
• 삼성카드                 (별도 그룹 제거 — 트리에 통합)
• 현대카드                 
```

- `parent_account_id`로 묶음
- 부모 행 트리 ChevronRight + 자식은 들여쓰기 (Padding left 24)
- AccountFormSheet에서 `parent_account_id` Dropdown 추가 (NULL 또는 cash type 계좌만 선택)

### 5.6 AccountFormSheet (확장)

기존 필드에 추가:
```
┌───────────────────────────┐
│ 계좌 추가/수정            │
├───────────────────────────┤
│ 계좌명 / type / 잔액 ... │   (M1 동일)
│                           │
│ [type=credit_card 일 때만]│
│ 결제일  [25 ▾]            │   (1-31, 28일까지 안전)
│                           │
│ [type=cash가 아닐 때만]   │
│ 부모 계좌  [신한 주거래▾] │   (트리 매핑)
│                           │
│ 비고 / 활성 ...           │
└───────────────────────────┘
```

---

## 6. State Management (M2 신규 Provider)

| Provider | Type | 책임 |
|----------|------|------|
| `analyticsRepositoryProvider` | `Provider<AnalyticsRepository>` | DI |
| `categoryDonutProvider` | `FutureProvider.family<List<CategorySegment>, DateTime>` | 월별 도너츠 |
| `fixedVariableSeriesProvider` | `FutureProvider<List<MonthlySplitSeries>>` | 라인 차트 |
| `cardDetailRepositoryProvider` | `Provider<CardDetailRepository>` | DI |
| `cardDetailProvider` | `FutureProvider.family<CardDetailMetrics, int>` | 카드별 상세 |
| `searchFilterProvider` | `NotifierProvider<SearchFilter>` | List 검색 폼 상태 |
| `searchResultsProvider` | `FutureProvider<List<TxRow>>` | 검색 결과 (filter watch) |

---

## 7. Test Plan

### 7.1 Unit Tests (M2 신규)

- `AnalyticsRepository` (in-memory Drift 또는 mock data):
  - empty input → empty segments
  - 월 경계 — 이전/다음달 거래 포함 안됨
  - 카테고리별 합계 정확
  - 도너츠는 totalAmount desc 정렬
  - 고정/변동 분리 정확
  - 12개월 윈도우 + 빈달
- `CardDetailRepository.computeNextDueDate` (순수):
  - 결제일이 오늘 이후 → 이번달
  - 결제일이 오늘 이전 → 다음달
  - dueDay = 31 (단축월) → 28로 clamp
  - dueDay NULL → 반환 NULL
- `TransactionsDao.search` (in-memory Drift):
  - keyword 매칭 (LIKE)
  - 기간 필터
  - 계좌 필터 (from + to OR)
  - type 필터
  - 모든 필터 조합

### 7.2 Integration Tests (FR-31, M1 deferred 청산)

`test/integration/transaction_repository_test.dart`:
- TransactionRepository.add expense → 계좌 잔액 감소 + tx insert + queue enqueue 모두 commit
- add transfer → 양 계좌 정확히 +/- 적용
- add valuation → 계좌 잔액이 amount 절대값으로 갱신 + delta 정확
- update → 이전 delta undo + 새 delta 적용
- delete → delta undo + soft delete

`test/integration/balance_reconciler_test.dart` (보너스):
- 계좌 3개 + 거래 10건 임의 입력 → reconciler 결과 모두 isClean
- 의도적으로 raw SQL로 잔액 조작 → drift 감지

### 7.3 Migration Tests

- v2 → v3 in-memory test: v2 schema로 시작 → v3 마이그레이션 → due_day 컬럼 존재 + 기존 행 보존

### 7.4 Manual Verification (M2 DoD)

- [ ] M1 데이터 보존 — 디바이스에서 v3 마이그레이션 실행 후 거래/계좌 모두 표시
- [ ] credit_card 추가 → due_day 입력 → 카드 상세에서 D-day 정확
- [ ] 분석 탭 → 이번 달 도너츠 + 6개월 라인 차트 실제 데이터 표시
- [ ] List SearchBar — 키워드 입력 → 결과 ≤ 100ms
- [ ] 계좌 트리 — 카드 부모 설정 후 들여쓰기 표시
- [ ] APK 크기 ≤ 30MB

---

## 8. Sync Impact

### 8.1 accounts 시트 변경

```
Before:  name | type | balance | parent_account | is_active | updated_at
After:   name | type | balance | parent_account | is_active | updated_at | due_day
```

- `SheetLayout.accountsHeader` 7번째 컬럼 추가 → `accountsOverwriteRange` `A1:G`
- `SyncService._pushAccountsSnapshot._accountToRow`에 due_day 매핑 추가
- 기존 사용자: 첫 동기화 시 `ensureSheet`이 헤더 행 자동 갱신 (멱등). 기존 6열 데이터에는 빈 G열 추가됨.

### 8.2 transactions / monthly_summary 시트

**변경 없음** — 거래 자체에 due_day 영향 없음, 월별 집계도 영향 없음.

---

## 9. Performance & Security

| 영역 | 목표 | 전략 |
|------|------|------|
| 분석 화면 진입 | ≤ 300ms | Drift 인덱스 + Riverpod cache |
| 검색 응답 | ≤ 100ms | occurred_at 인덱스 + 250ms debounce + LIKE는 keyword 있을 때만 |
| 마이그레이션 시간 | ≤ 1s (1만 행 가정) | addColumn은 O(1) 메타데이터 변경 |
| APK 증가 | ≤ +3MB (fl_chart) | release build의 tree-shake로 사용 차트만 포함 |
| Security | 변경 없음 | M1 정책 유지 |

---

## 10. Risks (Plan §7과 동기화)

| Risk | Design 대응 |
|------|-------------|
| 마이그레이션 데이터 손실 | `addColumn`만 사용 (idempotent). v2→v3 in-memory 테스트로 사전 검증 |
| 6탭 NavigationBar 좁아짐 | Material 3 NavigationBar는 6탭까지 라벨 표시 OK (Flutter docs 확인). 짧은 라벨 사용 |
| 카드 결제일 변동 (25일/30일 변동) | M2는 단일 due_day. M3에서 due_day_secondary 추가 검토 |
| 검색 성능 | 인덱스 + debounce + LIKE 한정 적용 + limit 200 |
| fl_chart 학습 곡선 | 도너츠+라인 2종만, 공식 예제 그대로. 색상은 ColorScheme tertiary/primary 활용 |
| Sheets 시트 헤더 mismatch (기존 사용자) | `ensureSheet`가 헤더 행 자동 갱신. 데이터 행은 자동으로 새 컬럼 빈값 |
| sqlite3 native binary on Windows | dev_dependencies sqlite3 + 명시적 setup 가이드. CI는 GitHub Actions ubuntu (자동 설치) |

---

## 11. Implementation Guide

### 11.1 의존성 추가 (pubspec.yaml)

```yaml
dependencies:
  ...M1 deps...
  fl_chart: ^0.69.0   # 차트 (도너츠 + 라인)

dev_dependencies:
  ...M1 dev deps...
  sqlite3: ^2.5.0     # in-memory Drift 통합 테스트용 (Windows 바이너리는 OS 의존)
```

### 11.2 구현 순서 (의존 DAG)

```
1. pubspec.yaml + Drift v3 마이그레이션 + tables.dart due_day      (M2.1)
2. AccountFormSheet due_day + parent_account_id 입력                (M2.1)
3. CardDetailRepository + CardDetailScreen                          (M2.1)
4. AccountsScreen 트리 표시                                         (M2.1)
5. analytics module (domain + data)                                 (M2.2)
6. fl_chart 차트 위젯 (도너츠 + 라인)                              (M2.2)
7. AnalyticsScreen 메인                                             (M2.2)
8. router.dart 6탭 추가                                             (M2.2)
9. TransactionsDao.search()                                         (M2.3)
10. SearchBar widget + 칩 필터                                      (M2.3)
11. ListScreen 통합 (SearchBar 추가)                                (M2.3)
12. transfer-to-credit_card 안내 (FR-30)                            (M2.4)
13. sqlite3 dev_dep + Repository 통합 테스트 5건                    (M2.4)
14. Sheets accounts 시트 컬럼 동기화                                (M2.4)
15. APK 빌드 검증 + 디바이스 실증                                   (M2.4)
```

### 11.3 Session Guide (Module Map)

| Session | Scope Key | 포함 | 예상 LOC |
|---------|-----------|------|---------:|
| **session-1** | `schema-card` | Drift v3 마이그레이션 + tables.due_day + AccountForm 확장 + CardDetailScreen + AccountsScreen 트리 | ~330 |
| **session-2** | `analytics-tab` | analytics module(domain/data/ui) + fl_chart + AnalyticsScreen + router 6탭 | ~280 |
| **session-3** | `search-filter` | TransactionsDao.search + SearchBar + 칩 필터 + ListScreen 통합 | ~180 |
| **session-4** | `tree-tests` | sqlite3 dev_dep + Repository 통합 테스트 5건 + transfer-to-card 안내 + Sheets 시트 컬럼 sync + APK 검증 | ~160 |

**총 ~950 LOC** (Plan 추정 ~900과 일치).

### 11.4 검증 명령어 (M2 DoD)

```bash
flutter pub get
dart run build_runner build --force-jit --delete-conflicting-outputs
flutter analyze        # 0 issues
flutter test           # M1 63 + M2 신규 ~15 = ~78
flutter build apk --debug --target-platform=android-arm64
```

---

## 12. Open Questions

| # | Question | Owner | Resolve By |
|---|----------|-------|-----------|
| Q1 | 카드 결제일이 매월 변동하는 사용자 처리 — 단일 due_day로 충분한가? | 본인 (사용 후) | M3 |
| Q2 | 분석 탭 라인 차트가 6개월 이전 데이터 부족 시 (M1 시작이 4월 → 11월~3월 모두 0) UX는? | 본인 | M2.2 시작 전 |
| Q3 | List 칩 필터의 "기간" 기본값 — 전체 vs 이번달? | 본인 | M2.3 직전 |
| Q4 | 트리에서 비활성 부모 자식은 어떻게 표시? | 본인 | M2.1 직전 |
| Q5 | 검색 결과 limit 200 hit 시 "더 보기" UX vs 단순 truncate? | 본인 | M2.3 직전 |

---

## 13. Decision Record (Plan + Design)

| 결정 | 선택 | 근거 |
|------|------|------|
| Architecture | Option C (Pragmatic) | M1과 동일 철학, analytics 모듈만 격리 |
| Chart library | fl_chart | Flutter 1위, MIT, 도너츠+라인 모두 지원, ~3MB APK 증가 |
| Card detail entry | AccountsScreen drill-down | 자연스러운 navigation, 5탭 유지 |
| Analytics tab | 새 6번째 탭 | 명확한 분리, 기존 화면 부담 없음 |
| Search entry | List SearchBar | Tx 탐색의 자연스러운 위치 |
| Migration style | core/db/migrations/v{n}_to_{m}.dart 분리 | 미래 확장 표준화 |
| Search keyword | memo만 (LIKE) | 단순 + 인덱스 활용 + 충분한 효용 |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-28 | Initial M2 design (Option C). 11 신규 + 7 수정 파일, ~950 LOC, 4 세션 구분. |
