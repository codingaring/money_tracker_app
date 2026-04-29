---
template: design
version: 2.0
feature: budget-tracker
date: 2026-04-28
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.2.0"
level: Dynamic
architecture: Option C — Pragmatic (Repository + 별도 SyncService + Dashboard projector)
basePlan: docs/01-plan/features/budget-tracker.plan.md
specReference: .claude/detail.md
---

# Personal Budget Tracker — Design Document v2.0

> **Architecture**: Pragmatic — Feature 모듈에 Repository, sync/dashboard 같은 횡단/조회 관심사는 전용 모듈로 격리.
>
> **v2.0 핵심 변경**: 4-type Tx + Accounts 통합 관리 + 잔액 자동갱신 (atomic) + 홈 대시보드 + 3-시트 Sheets 동기화.

---

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 회계 정합성 (4-type 모델) + 데이터 주권 (Sheets) + 가용 현금 가시성 |
| **WHO** | 본인 1인 / Android / Google 1 계정 |
| **RISK** | 잔액 갱신 트랜잭션 일관성 / OAuth 셋업 / 카드 발생주의 사용자 혼동 / Doze |
| **SUCCESS** | 5초 입력 / 가용 현금 정확 / 30일 사용 / 3 시트 자동 누적 |
| **SCOPE (M1)** | Accounts + 4-type Tx + 잔액 자동갱신 + 홈 대시보드 + 3 시트 동기화 |

---

## 1. Overview

### 1.1 목적

Plan v0.2의 도메인 인바리언트(잔액 무결성, type별 필드 정합성, 카테고리 kind 일치)를 깨지 않으면서, 5초 입력 SLA + 3-시트 자동 동기화를 양립시키는 모듈 구조와 데이터/제어 흐름을 정의한다.

### 1.2 적용 범위

| 항목 | 포함 (M1) | 제외 |
|------|----------|------|
| Flutter Android 앱 | ✅ | iOS / Web / Desktop |
| Drift SQLite 스키마 v2 (5 테이블) | ✅ | 마이그레이션은 M2부터 표준화 |
| **5화면**: 홈/입력/목록/계좌관리/설정 | ✅ | 카드별 보기, 카테고리 분석, 계좌 트리 (M2) |
| Google OAuth + Sheets API v4 | ✅ | 양방향 sync |
| **3 시트** 자동 동기화 (transactions/accounts/monthly_summary) | ✅ | 다중 시트 파일 분리 |
| 잔액 자동갱신 (atomic) + 무결성 검증 | ✅ | 거래 라인 분할 (line items) |

### 1.3 참조 문서

- Plan v0.2: [`docs/01-plan/features/budget-tracker.plan.md`](../../01-plan/features/budget-tracker.plan.md)
- Spec source: [`.claude/detail.md`](../../../.claude/detail.md)
- 외부: [Sheets API v4](https://developers.google.com/sheets/api/reference/rest/v4) / [google_sign_in](https://pub.dev/packages/google_sign_in) / [drift](https://pub.dev/packages/drift) / [workmanager](https://pub.dev/packages/workmanager)

---

## 2. Architecture

### 2.1 모듈 분할 (v2.0)

```
money_tracker_app/lib/
├── main.dart                                # ProviderScope, workmanager 등록
├── app/
│   ├── app.dart                             # MaterialApp + 테마 + 라우터
│   ├── router.dart                          # GoRouter (5 라우트)
│   └── theme.dart
├── features/
│   ├── accounts/                            # 신규
│   │   ├── ui/
│   │   │   ├── accounts_screen.dart         # 계좌 목록·CRUD
│   │   │   └── account_form.dart
│   │   ├── domain/account.dart              # AccountType enum
│   │   └── data/
│   │       ├── account_repository.dart
│   │       ├── accounts_dao.dart            # adjustBalance, setBalance
│   │       └── account_seed.dart            # (선택) 초기 시드
│   ├── categories/
│   │   ├── domain/category.dart             # CategoryKind enum
│   │   └── data/
│   │       ├── category_repository.dart
│   │       └── category_seed.dart           # 변동/고정 분리 시드
│   ├── transactions/
│   │   ├── ui/
│   │   │   ├── input_screen.dart            # type별 동적 폼 (4-type 분기)
│   │   │   └── list_screen.dart
│   │   ├── domain/
│   │   │   ├── transaction.dart             # TxType + NewTransaction
│   │   │   └── delta_calculator.dart        # type별 delta 산출 (순수 함수)
│   │   └── data/
│   │       ├── transactions_dao.dart
│   │       └── transaction_repository.dart  # 잔액 갱신 + enqueue
│   ├── dashboard/                           # 신규
│   │   ├── ui/home_screen.dart              # 7 지표
│   │   ├── domain/dashboard_metrics.dart    # NetWorth, AvailableCash 등 값 객체
│   │   └── data/dashboard_repository.dart   # 집계 쿼리 (reactive)
│   ├── auth/
│   │   ├── data/google_auth_service.dart
│   │   └── ui/auth_required_banner.dart
│   ├── sync/
│   │   ├── domain/
│   │   │   ├── sync_op.dart
│   │   │   ├── sync_enqueuer.dart
│   │   │   └── sync_status.dart
│   │   ├── data/
│   │   │   ├── sync_queue_dao.dart
│   │   │   └── local_queue_enqueuer.dart    # SyncEnqueuer 구현체
│   │   └── service/
│   │       ├── sync_service.dart            # 3-시트 오케스트레이션
│   │       ├── sheets_sync_worker.dart      # workmanager 콜백
│   │       └── monthly_aggregator.dart      # monthly_summary 집계
│   └── settings/
│       └── ui/settings_screen.dart
├── core/
│   ├── db/
│   │   ├── app_database.dart
│   │   └── tables.dart                      # 5 테이블
│   └── secure/secure_storage.dart
└── infrastructure/
    └── sheets/
        ├── sheets_client.dart               # 3-시트 op (append, overwrite, upsert)
        └── sheet_layout.dart                # 시트별 헤더·범위 상수
```

### 2.2 레이어 책임 (불변식 강조)

| 레이어 | 책임 | 핵심 불변식 |
|--------|------|-----------|
| `ui/` | 화면, 입력 검증 | UI 검증은 보조. 도메인 검증은 Repository에서 |
| `domain/` | 모델, enum, 순수 계산(delta_calculator) | 순수 — DB/네트워크 의존 금지 |
| `data/` | Drift DAO + Repository | **잔액 변경은 반드시 Drift transaction 내부에서만** |
| `service/` (sync) | 큐 drain, Sheets 호출, 토큰 갱신 | **Repository는 Sheets를 직접 호출하지 않는다** |
| `infrastructure/sheets/` | 외부 SDK 어댑터 | 비즈니스 로직 없음 |

### 2.3 의존성 그래프

```
       ┌──────────────────────────┐
       │  UI (Riverpod consumers) │
       └────────────┬─────────────┘
                    │
   ┌────────┬───────┼───────┬────────────┐
   ▼        ▼       ▼       ▼            ▼
┌──────┐┌──────┐┌──────┐┌──────────┐┌──────────┐
│Acct  ││Cat   ││Tx    ││Dashboard ││Settings  │
│Repo  ││Repo  ││Repo  ││Repo      ││ + Auth   │
└──┬───┘└──┬───┘└──┬───┘└────┬─────┘└────┬─────┘
   │       │       │         │           │
   │       │       ▼         │           │
   │       │  ┌────────┐     │           │
   │       │  │SyncEnq │     │           │
   │       │  │(iface) │     │           │
   │       │  └───┬────┘     │           │
   │       │      │ impl     │           │
   │       │      ▼          │           │
   │       │ ┌─────────────┐ │           │
   │       │ │SyncService  │─┼─▶[Sheets │
   │       │ │+ Worker     │ │  Client] │
   │       │ │+ MonthlyAgg │ │           │
   │       │ └──────┬──────┘ │           │
   ▼       ▼        ▼        ▼           ▼
┌─────────────────────────────────────────────┐
│              AppDatabase (Drift)             │
│  accounts · categories · transactions ·      │
│  sync_queue · kv_store                       │
└─────────────────────────────────────────────┘
```

---

## 3. Data Model (Drift Schema v2)

### 3.1 `accounts`

| Column | Type | 제약 | 설명 |
|--------|------|------|------|
| `id` | INTEGER | PK AUTOINCREMENT | |
| `name` | TEXT | UNIQUE NOT NULL | 계좌명 |
| `type` | TEXT | NOT NULL (enum) | cash/investment/savings/real_estate/credit_card/loan |
| `balance` | INTEGER | NOT NULL DEFAULT 0 | KRW 정수, 부채는 음수 누적 |
| `is_active` | INTEGER | NOT NULL DEFAULT 1 | 0/1 |
| `parent_account_id` | INTEGER | NULL FK→accounts.id | 카드↔통장 매핑 (M2 트리 UI용) |
| `note` | TEXT | NULL | 비고 |
| `sort_order` | INTEGER | NOT NULL DEFAULT 0 | UI 정렬 |
| `created_at` | DATETIME | NOT NULL DEFAULT now | |
| `updated_at` | DATETIME | NOT NULL DEFAULT now | balance 변경 시 함께 갱신 |

**Index**: `idx_acc_active_sort (is_active DESC, sort_order ASC)`

### 3.2 `categories`

| Column | Type | 제약 |
|--------|------|------|
| `id` | INTEGER | PK AUTOINCREMENT |
| `name` | TEXT | UNIQUE NOT NULL |
| `kind` | TEXT | NOT NULL (`expense`/`income`) |
| `is_fixed` | INTEGER | NOT NULL DEFAULT 0 (변동/고정비 구분) |
| `sort_order` | INTEGER | NOT NULL DEFAULT 0 |

**Seed (Plan §10.1 + detail.md §90~106)**:
- 지출 변동: 식비, 교통, 쇼핑, 여가, 의료, 경조사, 기타
- 지출 고정: 월세/관리비, 통신비, 구독료, 보험료, 대출이자
- 수입: 급여, 이자, 배당, 환급, 기타수입

### 3.3 `transactions`

| Column | Type | 제약 |
|--------|------|------|
| `id` | INTEGER | PK AUTOINCREMENT |
| `local_id` | TEXT | UNIQUE NOT NULL (UUID v4 — Sheets row 매칭) |
| `type` | TEXT | NOT NULL — `expense`/`income`/`transfer`/`valuation` |
| `amount` | INTEGER | NOT NULL > 0 (절대값) |
| `category_id` | INTEGER | NULL FK→categories.id |
| `from_account_id` | INTEGER | NULL FK→accounts.id |
| `to_account_id` | INTEGER | NULL FK→accounts.id |
| `from_delta` | INTEGER | NULL — from 계좌에 적용된 잔액 변동 (signed) |
| `to_delta` | INTEGER | NULL — to 계좌에 적용된 잔액 변동 (signed) |
| `memo` | TEXT | NULL |
| `occurred_at` | DATETIME | NOT NULL — 거래 발생일 (카드는 사용일) |
| `created_at` | DATETIME | NOT NULL DEFAULT now |
| `updated_at` | DATETIME | NOT NULL DEFAULT now |
| `deleted_at` | DATETIME | NULL — soft delete |
| `synced_at` | DATETIME | NULL |

**Index**: `idx_tx_occurred_desc (deleted_at, occurred_at DESC)`, `idx_tx_unsynced (synced_at) WHERE synced_at IS NULL`

**Type별 필드 사용 표**:

| type | from_account | to_account | category | from_delta | to_delta |
|------|:----:|:----:|:----:|:----:|:----:|
| `expense` | 필수 | NULL | 필수(kind=expense) | -amount | NULL |
| `income` | NULL | 필수 | 필수(kind=income) | NULL | +amount |
| `transfer` | 필수 | 필수 (≠ from) | NULL | -amount | +amount |
| `valuation` | NULL | 필수 | NULL | NULL | (amount - prev_balance) |

> `from_delta` / `to_delta`는 거래 시점의 실제 잔액 변동량을 저장. **수정/삭제 undo를 단순화**하기 위함 (Repository가 이전 delta의 부호 반전만 적용하면 됨).

### 3.4 `sync_queue`

| Column | Type | 제약 |
|--------|------|------|
| `id` | INTEGER | PK AUTOINCREMENT |
| `local_id` | TEXT | NOT NULL — transactions.local_id 참조 (논리적, FK 비강제) |
| `op` | TEXT | NOT NULL — `insert`/`update`/`delete` |
| `enqueued_at` | DATETIME | NOT NULL DEFAULT now |
| `attempt_count` | INTEGER | NOT NULL DEFAULT 0 |
| `last_attempt_at` | DATETIME | NULL |
| `last_error` | TEXT | NULL |

> sync_queue는 **transactions 시트만** 대상. accounts/monthly_summary는 매 cycle 풀-덮어쓰기 (큐 불필요).

### 3.5 `kv_store`

| Column | Type |
|--------|------|
| `key` | TEXT PK |
| `value` | TEXT |

**Keys (M1)**: `spreadsheet_id`, `last_sync_at`, `last_accounts_sync_at`, `last_monthly_sync_at`, `seed_version`

### 3.6 Sheets 시트 스키마

#### Sheet 1: `transactions` (append-only + tx_id 멱등)

| date | type | amount | category | from_account | to_account | memo | tx_id (= local_id) | synced_at |
|---|---|---|---|---|---|---|---|---|

#### Sheet 2: `accounts` (스냅샷 — 매 cycle 전체 덮어쓰기)

| name | type | balance | parent_account | is_active | updated_at |
|---|---|---|---|---|---|

#### Sheet 3: `monthly_summary` (앱이 집계해서 push)

| year_month | income | expense | net | net_worth_end |
|---|---|---|---|---|

> `monthly_summary`는 최근 12개월만 push (오래된 월은 Sheets에서 보존, 앱은 신경 안 씀).

---

## 4. Component Specifications

### 4.1 `AccountRepository`

```dart
class AccountRepository {
  Stream<List<Account>> watchAll({bool activeOnly = true});
  Future<Account> create(NewAccount draft);
  Future<void> update(Account a);
  Future<void> deactivate(int id);  // soft — 잔액 0이어야 OK (M1은 강제 안 함, 경고만)
  Future<Account?> findById(int id);
}
```

### 4.2 `AccountsDao` — 잔액 변경 단일 진입점

```dart
@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase> with _$AccountsDaoMixin {
  Future<void> adjustBalance(int accountId, int delta);  // balance += delta
  Future<int> setBalance(int accountId, int newBalance); // returns previous balance (valuation undo용)
  Future<int?> readBalance(int accountId);
}
```

> **불변식**: `accounts.balance` 변경은 오직 이 DAO를 통해서만. Repository.update에서 Drift `update(accounts)` 직접 호출 금지.

### 4.3 `DeltaCalculator` (순수 함수)

```dart
// features/transactions/domain/delta_calculator.dart
class TxDeltas {
  final int? fromDelta;
  final int? toDelta;
  const TxDeltas({this.fromDelta, this.toDelta});
}

class DeltaCalculator {
  /// Pure function. No DB access for expense/income/transfer.
  /// For valuation, caller must supply prevBalance.
  static TxDeltas compute({
    required TxType type,
    required int amount,
    int? prevBalanceForValuation,
  }) {
    switch (type) {
      case TxType.expense:
        return TxDeltas(fromDelta: -amount);
      case TxType.income:
        return TxDeltas(toDelta: amount);
      case TxType.transfer:
        return TxDeltas(fromDelta: -amount, toDelta: amount);
      case TxType.valuation:
        if (prevBalanceForValuation == null) {
          throw ArgumentError('valuation requires prevBalance');
        }
        return TxDeltas(toDelta: amount - prevBalanceForValuation);
    }
  }

  /// Inverse — for undo on update/delete.
  static TxDeltas invert(TxDeltas d) => TxDeltas(
        fromDelta: d.fromDelta == null ? null : -d.fromDelta!,
        toDelta: d.toDelta == null ? null : -d.toDelta!,
      );
}
```

### 4.4 `TransactionRepository` (잔액 갱신 atomic 보장)

```dart
class TransactionRepository {
  Stream<List<TxRow>> watchAll();
  Future<TxRow> add(NewTransaction draft);
  Future<void> update(TxRow row, NewTransaction draft);
  Future<void> delete(String localId);
}
```

#### `add` 알고리즘

```
db.transaction {
  validate(draft)  // type-specific field invariants (FR-04)
  prevBalance = (type == valuation) ? accountsDao.readBalance(toAccountId) : null
  deltas = DeltaCalculator.compute(type, amount, prevBalance)
  
  insert tx with from_delta=deltas.fromDelta, to_delta=deltas.toDelta
  if deltas.fromDelta != null: accountsDao.adjustBalance(fromAccountId, deltas.fromDelta)
  if deltas.toDelta   != null: accountsDao.adjustBalance(toAccountId,   deltas.toDelta)
  
  syncEnqueuer.enqueue(localId, insert)  // best-effort, swallow exceptions
  return tx
}
```

#### `update` 알고리즘

```
db.transaction {
  oldRow = txDao.findByLocalId(localId)
  // 1) Undo old effect
  if oldRow.fromDelta != null: accountsDao.adjustBalance(oldRow.fromAccountId!, -oldRow.fromDelta!)
  if oldRow.toDelta   != null: accountsDao.adjustBalance(oldRow.toAccountId!,   -oldRow.toDelta!)
  
  // 2) Compute new deltas (valuation: prevBalance from CURRENT after undo)
  prevBalance = (newType == valuation) ? accountsDao.readBalance(newToId) : null
  newDeltas = DeltaCalculator.compute(newType, newAmount, prevBalance)
  
  // 3) Apply new effect + update tx
  txDao.updateByLocalId(localId, with newDeltas, syncedAt=null /* needs re-sync */)
  if newDeltas.fromDelta != null: accountsDao.adjustBalance(newFromId, newDeltas.fromDelta)
  if newDeltas.toDelta   != null: accountsDao.adjustBalance(newToId,   newDeltas.toDelta)
  
  syncEnqueuer.enqueue(localId, update)
}
```

#### `delete` 알고리즘 (soft)

```
db.transaction {
  row = txDao.findByLocalId(localId)
  if row.fromDelta != null: accountsDao.adjustBalance(row.fromAccountId!, -row.fromDelta!)
  if row.toDelta   != null: accountsDao.adjustBalance(row.toAccountId!,   -row.toDelta!)
  
  txDao.softDeleteByLocalId(localId)  // sets deleted_at
  syncEnqueuer.enqueue(localId, delete)
  // Hard delete happens in SyncService after Sheets row clear succeeds.
}
```

### 4.5 `DashboardRepository` (집계)

```dart
class DashboardMetrics {
  final int netWorth;             // sum(balance)
  final int cashAssets;           // sum(balance where type='cash')
  final int investmentAssets;     // sum(balance where type IN ('investment','savings'))
  final int creditCardBalance;    // sum(balance where type='credit_card') — negative
  final int availableCash;        // cashAssets + creditCardBalance
  final int currentMonthExpense;  // sum(amount where type='expense' AND occurred_at in current month)
  final int currentMonthIncome;   // sum(amount where type='income'  AND occurred_at in current month)
  
  const DashboardMetrics({...});
}

class DashboardRepository {
  Stream<DashboardMetrics> watchMetrics();  // reactive — accounts + transactions 변화 시 즉시 갱신
}
```

### 4.6 `SyncService` — 3-시트 오케스트레이션

```dart
class SyncFlushResult {
  final int txAppended, txUpdated, txCleared;
  final bool accountsSynced;
  final bool monthlySynced;
  final String? error;
}

class SyncService implements SyncEnqueuer {
  Future<void> enqueue({required String localId, required SyncOp op});  // → queue
  Future<SyncFlushResult> flush();
  Stream<SyncStatus> watchStatus();
}
```

#### `flush` 알고리즘

```
flush():
  if !auth.isSignedIn(): return SyncFlushResult.noAuth
  spreadsheetId = kv['spreadsheet_id'] ?? sheets.createSpreadsheet()
  ensureLayout(spreadsheetId)  // 3 시트 + 헤더 행 멱등 보장
  
  // 1) transactions sheet — queue 처리
  pending = queueDao.fetchOldest(50)
  for op in pending:
    case insert: sheets.appendRows("transactions", [row(op)])
                 txDao.markSynced(op.localId)
    case update: rowIndex = sheets.findRowByTxId("transactions", op.localId)
                 sheets.updateRow("transactions", rowIndex, row(op))
                 txDao.markSynced(op.localId)
    case delete: rowIndex = sheets.findRowByTxId("transactions", op.localId)
                 sheets.clearRow("transactions", rowIndex)
                 txDao.hardDelete(op.localId)
    queueDao.delete(op.id)
  
  // 2) accounts sheet — 매 cycle 전체 덮어쓰기 (스냅샷)
  allAccounts = accountsDao.readAll()
  sheets.overwriteRange("accounts", "A1:F", header + allAccounts.map(toRow))
  kv['last_accounts_sync_at'] = now
  
  // 3) monthly_summary — 최근 12개월 집계
  summaries = monthlyAggregator.compute(months: 12)
  sheets.overwriteRange("monthly_summary", "A1:E", header + summaries.map(toRow))
  kv['last_monthly_sync_at'] = now
  
  kv['last_sync_at'] = now
  return SyncFlushResult(...)
```

> **시간 비용 최적화**: accounts/monthly는 변경이 없는 cycle에도 덮어쓰기 (1 API call씩). 1인 사용 빈도 + Sheets 일일 쿼터 한참 여유 → 무시 가능.

### 4.7 `MonthlyAggregator` (순수 — 테스트 용이)

```dart
class MonthlySummary {
  final String yearMonth;  // 'YYYY-MM'
  final int income, expense, net, netWorthEnd;
}

class MonthlyAggregator {
  /// Pure aggregation — fed by repositories.
  static List<MonthlySummary> compute({
    required List<TxRow> transactions,
    required List<Account> accounts,
    required int months,  // last N months
    DateTime? now,
  });
}
```

### 4.8 `SheetsClient` (infrastructure — 비즈니스 로직 없음)

```dart
class SheetsClient {
  Future<String> createSpreadsheetIfMissing({required String title});
  Future<void> ensureSheet(String spreadsheetId, String sheetName, List<String> header);
  Future<void> appendRows(String spreadsheetId, String range, List<List<Object?>> rows);
  Future<int?> findRowByLocalId(String spreadsheetId, String range, String localId, int idColumnIndex);
  Future<void> updateRow(String spreadsheetId, int rowIndex, List<Object?> row);
  Future<void> clearRow(String spreadsheetId, int rowIndex);
  Future<void> overwriteRange(String spreadsheetId, String range, List<List<Object?>> values);
}
```

### 4.9 `GoogleAuthService`

```dart
class GoogleAuthService {
  Stream<bool> watchSignedIn();
  Future<void> signIn();   // scopes: spreadsheets, openid, email
  Future<void> signOut();
  Future<AuthClient?> authenticatedClient();
}
```

---

## 5. UI Specifications (5화면)

### 5.1 HomeScreen — 대시보드 7 지표 (FR-08)

```
┌─────────────────────────────────────┐
│ 가계부              [+ 거래] ⚙       │
├─────────────────────────────────────┤
│ 💰 가용 현금                        │
│        ₩ 2,847,500                  │   ← 가장 큰 글자, 강조
│ (현금 4,200,000 - 카드 1,352,500)   │
├─────────────────────────────────────┤
│ 순자산        ₩ 187,420,000         │
│ ─────────────────────────           │
│ 현금성 자산   ₩ 4,200,000           │
│ 투자 자산     ₩ 32,800,000          │
│ 카드 미결제   -₩ 1,352,500          │
├─────────────────────────────────────┤
│ 이번 달 (4월)                       │
│ 수입  +3,200,000   지출  -1,847,500 │
│ 순증감    +1,352,500                │
├─────────────────────────────────────┤
│ 동기화: 2분 전 ✅ (미동기화 0건)    │
└─────────────────────────────────────┘
```

- `DashboardRepository.watchMetrics()` → `StreamProvider<DashboardMetrics>`
- 카드 미결제 잔액은 Plan §1.3 가용 현금 공식의 핵심 → UI에서 강조
- 가용 현금 음수면 빨간색 + 경고 아이콘

### 5.2 InputScreen — type 동적 분기 (FR-16)

```
┌─────────────────────────────────────┐
│ ← 거래 추가                         │
├─────────────────────────────────────┤
│ 유형                                │
│ [지출][수입][이체][평가] ← Segmented│
├─────────────────────────────────────┤
│  (type=expense일 때:)               │
│  ₩ [_________]                      │
│  계좌    [신한 주거래        ▾]    │
│  카테고리[식비][교통][...]          │
│  메모   [_______________]           │
│  날짜   [2026-04-28 ▾]              │
│                                     │
│  (type=transfer일 때:)              │
│  ₩ [_________]                      │
│  보내는 [신한 주거래        ▾]    │
│  받는   [삼성카드           ▾]    │
│  메모   [_______________]           │
│                                     │
│  (type=valuation일 때:)             │
│  ₩ [_________]  ← "현재 평가금"     │
│  계좌   [키움 주식          ▾]    │
│  메모   [월말 평가금 갱신   ]       │
│                                     │
│ ┌─────────────────────────────┐    │
│ │      저장                   │    │
│ └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**type 선택 시 동적 폼**:
| type | 노출 필드 |
|------|----------|
| expense | amount + from_account + category(expense) + memo + date |
| income  | amount + to_account + category(income) + memo + date |
| transfer | amount + from + to (≠) + memo + date |
| valuation | amount(평가금 절대값) + to_account + memo + date |

**카드 안내**: from_account의 type이 credit_card면 "💳 카드값 출금이 아니라 사용내역인가요? 출금은 [이체]로 입력하세요" 한 줄 안내.

### 5.3 ListScreen — 거래 목록

```
┌─────────────────────────────────────┐
│ ← 거래 내역            [필터(M2)]   │
├─────────────────────────────────────┤
│ 2026-04-28                          │
│ ─────────────────                   │
│ 💸 식비       -12,000 신한          │
│ 🔄 카드값 결제 150,000 신한→삼성    │
│                                     │
│ 2026-04-27                          │
│ ─────────────────                   │
│ 💵 월급      +3,200,000 → 신한      │
│ 📈 키움 평가금 갱신 → 32,800,000    │
└─────────────────────────────────────┘
```

- 아이콘: expense 💸 / income 💵 / transfer 🔄 / valuation 📈
- 미동기화 행은 ⏳ 배지

### 5.4 AccountsScreen — 계좌 관리 (CRUD)

```
┌─────────────────────────────────────┐
│ ← 계좌                       [+]    │
├─────────────────────────────────────┤
│ 현금성                              │
│ • 신한 주거래   ₩ 4,200,000        │
│                                     │
│ 투자                                │
│ • 키움 주식    ₩ 32,800,000        │
│ • 우리 ISA     ₩ 8,500,000         │
│                                     │
│ 부채                                │
│ • 삼성카드    -₩ 1,352,500         │
│ • 전세 대출  -₩ 150,000,000        │
│                                     │
│ 비활성 (1)                          │
└─────────────────────────────────────┘
```

- 계좌 탭 → 상세 + 수정 (잔액 직접 수정 시 valuation tx 자동 생성?? — M2 결정. M1은 직접 수정 disable)

### 5.5 SettingsScreen

```
┌─────────────────────────────────────┐
│ ← 설정                              │
├─────────────────────────────────────┤
│ 계정                                │
│  🔵 kyk@hunik.kr      [로그아웃]   │
├─────────────────────────────────────┤
│ 동기화                              │
│  미동기화: 0건                      │
│  마지막 성공: 2분 전                │
│  [지금 동기화]                      │
├─────────────────────────────────────┤
│ Google Sheets                       │
│  [Sheets에서 보기 →]                │
│  시트 ID: 1abcXyz...                │
│  ─ transactions (3,247행)           │
│  ─ accounts (5행)                   │
│  ─ monthly_summary (12행)           │
├─────────────────────────────────────┤
│ 무결성                              │
│  [잔액 재계산 검증]  ← FR-18         │
└─────────────────────────────────────┘
```

---

## 6. Sync Sequence Diagrams

### 6.1 잔액 갱신 atomic (입력)

```
User    InputScreen   TxRepo    DeltaCalc   AccountsDao   TxDao   Queue
 │  tap저장 │           │          │            │           │       │
 │─────────▶│submit()   │          │            │           │       │
 │          │──────────▶│          │            │           │       │
 │          │           │ db.transaction {                          │
 │          │           │ ─validate(draft)                          │
 │          │           │   ───────▶│            │           │       │
 │          │           │   compute │            │           │       │
 │          │           │   ◀───────│            │           │       │
 │          │           │ ─insert tx with deltas                    │
 │          │           │   ───────────────────────▶│       │       │
 │          │           │ ─adjustBalance(from, fromDelta)           │
 │          │           │   ────────────────▶│      │       │       │
 │          │           │ ─adjustBalance(to, toDelta)               │
 │          │           │   ────────────────▶│      │       │       │
 │          │           │ ─enqueue(localId, insert)                 │
 │          │           │   ────────────────────────────────▶│      │
 │          │           │ }  /* commit */                           │
 │          │           │ TxRow                                     │
 │          │           │◀──────────                                │
 │          │ 토스트    │                                           │
 │          │◀──────────│                                           │
 │ (≤ 5s 완료) ────────────────────────────────────────────────────│
                                                                    │
 Reactive: Drift watch streams fire → ListScreen + Dashboard 갱신
```

### 6.2 3-시트 동기화 (배치)

```
WorkManager   SyncService     Queue   AccountsDao   MonthlyAgg   Sheets
   │  flush()    │              │         │            │           │
   │────────────▶│              │         │            │           │
   │             │ ensureLayout(spreadsheetId)                     │
   │             │───────────────────────────────────────────────▶│
   │             │              │         │            │           │
   │             │ /* Sheet 1: transactions */                     │
   │             │ fetchOldest(50)                                 │
   │             │─────────────▶│         │            │           │
   │             │  pending     │         │            │           │
   │             │◀─────────────│         │            │           │
   │             │ for each: append/update/clear → mark synced     │
   │             │───────────────────────────────────────────────▶│
   │             │                                                  │
   │             │ /* Sheet 2: accounts (snapshot) */              │
   │             │              ▶ readAll()                         │
   │             │ overwriteRange("accounts!A:F", rows)            │
   │             │───────────────────────────────────────────────▶│
   │             │                                                  │
   │             │ /* Sheet 3: monthly_summary */                  │
   │             │                          ▶ compute(months:12)   │
   │             │ overwriteRange("monthly_summary!A:E", rows)     │
   │             │───────────────────────────────────────────────▶│
   │             │                                                  │
   │             │ kv['last_sync_at'] = now                         │
   │  result     │                                                  │
   │◀────────────│                                                  │
```

### 6.3 거래 수정 시 잔액 undo + redo (트랜잭션 일관성)

```
TxRepo.update(row, newDraft):
  db.transaction {
    oldRow = txDao.findByLocalId(localId)
    
    /* 1) Undo old effect — invert old delta */
    if oldRow.fromDelta != null:
      accountsDao.adjustBalance(oldRow.fromAccountId, -oldRow.fromDelta)
    if oldRow.toDelta != null:
      accountsDao.adjustBalance(oldRow.toAccountId, -oldRow.toDelta)
    
    /* 2) Compute new deltas (valuation: prevBalance after undo) */
    prevBalance = (newType == valuation) 
      ? accountsDao.readBalance(newDraft.toAccountId) 
      : null
    newDeltas = DeltaCalculator.compute(newType, newAmount, prevBalance)
    
    /* 3) Apply new effect + persist */
    txDao.updateByLocalId(localId, with newDeltas, syncedAt=null)
    if newDeltas.fromDelta != null:
      accountsDao.adjustBalance(newDraft.fromAccountId, newDeltas.fromDelta)
    if newDeltas.toDelta != null:
      accountsDao.adjustBalance(newDraft.toAccountId, newDeltas.toDelta)
    
    syncEnqueuer.enqueue(localId, update)
  }
  /* 모든 단계가 단일 트랜잭션 — 부분 실패 시 전체 롤백 */
```

---

## 7. State Management (Riverpod)

| Provider | Type | 책임 |
|----------|------|------|
| `appDatabaseProvider` | `Provider<AppDatabase>` | Drift 싱글톤 |
| `accountRepositoryProvider` | `Provider<AccountRepository>` | DI |
| `accountsStreamProvider` | `StreamProvider<List<Account>>` | watchAll() |
| `categoryRepositoryProvider` | `Provider<CategoryRepository>` | DI |
| `categoriesProvider` | `FutureProvider.family<List<Category>, CategoryKind?>` | 시드 + DB |
| `transactionRepositoryProvider` | `Provider<TransactionRepository>` | DI |
| `transactionsStreamProvider` | `StreamProvider<List<TxRow>>` | watchAll() |
| `dashboardRepositoryProvider` | `Provider<DashboardRepository>` | DI |
| `dashboardMetricsProvider` | `StreamProvider<DashboardMetrics>` | 7 지표 reactive |
| `googleAuthProvider` | `StreamProvider<bool>` | 로그인 상태 |
| `syncServiceProvider` | `Provider<SyncService>` | DI |
| `syncStatusProvider` | `StreamProvider<SyncStatus>` | 미동기화 카운트 |
| `inputFormProvider` | `NotifierProvider<InputFormState>` | type별 폼 상태 |

### Init 순서 (main.dart)

```
main():
  1. WidgetsFlutterBinding.ensureInitialized()
  2. await AppDatabase.open()
  3. await CategorySeeder.run(db)   // 멱등
  4. await Workmanager().initialize(callbackDispatcher)
  5. Workmanager().registerPeriodicTask(
       "sheets-sync", "sheets-sync",
       frequency: 15min,
       constraints: networkConnected,
     )
  6. runApp(ProviderScope(child: App()))
```

---

## 8. Test Plan

### 8.1 Unit Tests (target ≥ 60% on Repository/Sync/Aggregator)

**`DeltaCalculator` (순수 함수 — 100% 커버리지 가능)**:
| 시나리오 | 기대 |
|----------|------|
| expense 5000 | fromDelta=-5000, toDelta=null |
| income 3200000 | fromDelta=null, toDelta=+3200000 |
| transfer 150000 | fromDelta=-150000, toDelta=+150000 |
| valuation 1200000, prevBalance=1000000 | toDelta=+200000 |
| valuation 800000, prevBalance=1000000 | toDelta=-200000 |
| valuation 없이 prevBalance NULL | throw ArgumentError |
| invert | 모든 부호 반전 |

**`TransactionRepository` (DB 의존 — Module-4에서 in-memory Drift로 통합 테스트)**:
- add expense → fromAccount.balance 감소 + tx insert + queue enqueue
- add transfer → 양쪽 계좌 정확히 +/-
- add valuation → toAccount.balance가 amount로 갱신
- update 시 old delta undo + new delta 적용 → 잔액 일관
- delete 시 delta undo
- enqueue throw → swallow (DB 변경은 commit)

**`MonthlyAggregator`**:
- 빈 입력 → 빈 list
- 단일 월 데이터 → income/expense/net 정확
- 12개월 경계 → 과거 데이터 자동 cutoff

**`SyncService.flush`**:
- queue empty + 첫 sync → ensureLayout + accounts/monthly 시트 작성
- transactions queue 처리 → 각 op 정확
- 네트워크 실패 → attempt_count++, partial 반환

### 8.2 Integration Tests (Module-4 이후)

- Drift in-memory + RecordingSheetsClient로 end-to-end 시나리오
  - 거래 5건 입력 → flush → 3 시트 모두 정확한 행 수
  - 거래 수정 → flush → transactions 시트 update + accounts 스냅샷 갱신

### 8.3 Invariant Tests (FR-18)

```
test('잔액 무결성: 임의 100건 거래 후 재계산 결과 일치', () {
  // 임의 type/account 조합 100건 add
  // sum(deltas) per account == accounts.balance
});
```

### 8.4 Manual Verification (M1 DoD)

- [ ] 5종 시드 계좌 + 4-type 거래 각 1건씩 입력 → 잔액 모두 정확
- [ ] 콜드스타트 → expense 1건 저장 ≤ 5초
- [ ] 비행기 모드 5건 → 복구 후 30분 내 3 시트 반영
- [ ] 카드 사용 → 다음 달 카드값 출금(transfer)까지 시뮬 → 카드 잔액 0 복귀
- [ ] 주식 valuation 갱신 후 순자산 즉시 반영

---

## 9. Security & Privacy

| 항목 | 처리 |
|------|------|
| OAuth Refresh Token | flutter_secure_storage (Android Keystore) |
| Access Token | 메모리 캐시 |
| Sheets ID | kv_store (DB 평문 — Sheets 자체가 본인 소유) |
| Crash 로그 | 로컬만 (외부 전송 없음) |
| 백업 | `android:allowBackup="false"` (Sheets로 자체 보관) |
| 권한 | INTERNET만 |

---

## 10. Performance Budget

| 지표 | 목표 |
|------|------|
| 콜드 스타트 → HomeScreen 렌더 | ≤ 1.5s |
| 대시보드 7 지표 집계 (1만 건 가정) | ≤ 200ms (인덱스 + 캐싱) |
| 저장 버튼 → 토스트 | ≤ 200ms |
| 목록 갱신 | ≤ 100ms |
| APK 크기 | ≤ 25MB |

---

## 11. Implementation Guide

### 11.1 의존성 (pubspec.yaml)

```yaml
dependencies:
  flutter: { sdk: flutter }
  cupertino_icons: ^1.0.8
  
  # M1 cumulative
  flutter_riverpod: ^2.5.1   # Module-5에서 추가
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.27
  path_provider: ^2.1.4
  path: ^1.9.0
  uuid: ^4.5.1
  intl: ^0.19.0              # 날짜 포매팅
  
  google_sign_in: ^6.2.0     # Module-3
  googleapis: ^13.0.0
  googleapis_auth: ^1.6.0
  flutter_secure_storage: ^9.2.0
  
  workmanager: ^0.5.2        # Module-4
  go_router: ^14.0.0         # Module-5
  url_launcher: ^6.3.0

dev_dependencies:
  flutter_test: { sdk: flutter }
  flutter_lints: ^6.0.0
  drift_dev: ^2.18.0
  build_runner: ^2.4.13
  mocktail: ^1.0.4
```

> **build_runner 호출 시 `--force-jit` 필수** (Dart 3.10 + sqlite3 hooks 호환성).

### 11.2 구현 순서 (의존 DAG)

```
1. core/db/tables.dart + app_database.dart       (Module-1)
2. accounts/data + categories/data + seeds        (Module-1)
3. transactions/{domain (DeltaCalculator), data}  (Module-2)
4. infrastructure/sheets/sheets_client.dart       (Module-3)
5. auth/data/google_auth_service.dart             (Module-3)
6. sync/{data, service} + monthly_aggregator      (Module-4)
7. dashboard/{data, domain}                       (Module-5)
8. app/{router, theme} + main.dart + workmanager  (Module-6)
9. ui (home → input → list → accounts → settings) (Module-7)
10. android Manifest + 빌드                       (Module-8)
```

### 11.3 Session Guide (Module Map v2.0)

| Module | Scope Key | 포함 파일 | 예상 LOC | 의존 |
|--------|-----------|-----------|----------|------|
| **module-1** | `db-foundation` | core/db/* + accounts/{domain,data}/* + categories/{domain,data}/* + sync/domain/* | ~520 | — |
| **module-2** | `transactions-data` | features/transactions/{domain (incl. DeltaCalculator), data}/* | ~380 | module-1 |
| **module-3** | `sheets-auth-infra` | infrastructure/sheets/* + auth/data/* | ~340 | — (1·2와 병렬 가능) |
| **module-4** | `sync-service` | features/sync/{data, service}/* (+ MonthlyAggregator) | ~480 | module-2, module-3 |
| **module-5** | `dashboard-data` | features/dashboard/{domain, data}/* | ~180 | module-2 |
| **module-6** | `app-shell` | main.dart + app/* + workmanager 등록 | ~180 | module-4, module-5 |
| **module-7** | `ui-screens` | features/{dashboard, transactions, accounts, settings}/ui/* + auth/ui/* | ~750 | module-6 |
| **module-8** | `android-build` | AndroidManifest.xml + 빌드 검증 | ~30 | module-7 |

**Recommended Session Plan (4-5 세션)**:

| 세션 | Scope | 산출물 |
|------|-------|--------|
| Session 1 | `module-1,module-2` | 5 테이블 스키마 + 4-type Tx Repo + 잔액 자동갱신 + DeltaCalculator/Repository unit test |
| Session 2 | `module-3,module-4` | Auth + Sheets + 3-시트 SyncService (Sheets에 시드 1건 push 검증) |
| Session 3 | `module-5,module-6` | Dashboard 집계 + app shell + workmanager |
| Session 4 | `module-7` | 5 화면 모두 구현 (사용 가능한 상태) |
| Session 5 | `module-8` | APK + 핸드폰 설치 + DoD 체크 |

### 11.4 검증 명령어

```bash
flutter pub get
dart run build_runner build --force-jit --delete-conflicting-outputs
flutter analyze
flutter test
flutter build apk --release --split-per-abi
```

---

## 12. Open Questions

| # | Question | Owner | Resolve By |
|---|----------|-------|-----------|
| Q1 | GCP OAuth client ID 사전 발급? | 본인 | Module-3 시작 전 |
| Q2 | workmanager 주기 15분 vs 5분 | 본인 | 사용 1주 후 |
| Q3 | 시트 이름 — `transactions`/`accounts`/`monthly_summary` 영문 고정 vs 한글? | 본인 | Module-4 직전 |
| Q4 | 계좌 탭에서 잔액 직접 수정 허용? (valuation tx 자동 생성?) | 본인 | Module-7 |
| Q5 | 시드 계좌 미리 등록 vs 첫 실행 시 사용자가 직접? | 본인 | Module-1 |
| Q6 | 카드값 결제 transfer 입력 시 카테고리 "카드값" 강제? (현재 transfer는 category NULL) | 본인 | Module-7 |

---

## 13. Risks (Plan §7과 동기화)

| Risk | Design 대응 |
|------|-------------|
| 잔액 트랜잭션 일관성 | 모든 잔액 변경 = AccountsDao 단일 진입점 + Drift transaction 내부에서만. delta 컬럼으로 undo 단순화 |
| OAuth/Sheets 셋업 | Module-3 가장 먼저 (병렬 가능), 수동 sanity check |
| workmanager Doze | foreground 진입 시 즉시 1회 flush 트리거 |
| Sheets row 추적 손실 | tx_id 컬럼 (= local_id) + LRU 캐시 + fresh search fallback |
| Drift 마이그레이션 | M1은 v2 고정. v2→v3 마이그레이션은 M2부터 |
| 카드 발생주의 사용자 혼동 | 입력 화면에서 credit_card 계좌 선택 시 안내 텍스트 |
| valuation undo 복잡 (이전 평가금 모름) | from_delta/to_delta 컬럼에 거래 시점의 delta 저장 → undo 시 부호만 반전 |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-04-28 | Initial design (Option C, 단순 expense/income) | kyk@hunik.kr |
| **2.0** | **2026-04-28** | **`.claude/detail.md` 반영. 5 테이블 (accounts 신규), 4-type Tx, DeltaCalculator + delta 컬럼으로 atomic 잔액 갱신, Dashboard 모듈 + 7지표, 3-시트 SyncService, Module Map 8개 재산정.** | **kyk@hunik.kr** |
