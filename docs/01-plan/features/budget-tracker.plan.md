---
template: plan-plus
version: 2.0
feature: budget-tracker
date: 2026-04-28
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.2.0"
level: Dynamic
specReference: .claude/detail.md
---

# Personal Budget Tracker (가계부) Planning Document — v2.0

> **Summary**: Android 전용 1인 가계부 앱. **복식부기 단순화** 모델 (4-type 거래 + Accounts 통합 관리) + 로컬-퍼스트 SQLite + Google Sheets 3-시트 자동 동기화.
>
> **Project**: personal-workspace
> **Version**: 0.2.0
> **Status**: Updated (incorporating `.claude/detail.md`)

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | 단순 "지출/수입" 분류로는 카드 사용·자산 이동·평가금 변동을 정확히 표현 못 해서 순자산이 왜곡되고, 결국 가계부와 실제 통장이 안 맞는다. |
| **Solution** | 복식부기 단순화 — 거래를 expense/income/transfer/valuation 4종으로 구분하고, 모든 자산·부채를 Accounts로 통합 관리. 카드 사용은 발생주의로 사용 시점에 지출 인식. 잔액은 거래마다 자동 갱신. |
| **Function/UX Effect** | 홈 대시보드에서 7개 핵심 지표 한눈에 (순자산/현금성/투자/카드미결제/**가용 현금**/월지출/월수입). 본인 Sheets에 transactions append + accounts 스냅샷 + monthly_summary 집계 3 시트 자동 누적. |
| **Core Value** | 회계 정합성 × 데이터 주권. 실제 쓸 수 있는 돈("가용 현금")을 매 순간 정확히 알고, 본인 Sheets에 영구 보관되는 분석 가능한 원데이터. |

---

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 회계 정합성 (4-type 모델) + 데이터 주권 (Sheets) + 가용 현금 가시성 ("실제 쓸 수 있는 돈"). |
| **WHO** | 본인 1인 / Android 단일 디바이스 / Google 계정 1개. |
| **RISK** | (1) 4-type Tx + 잔액 자동갱신의 일관성 (트랜잭션 무결성) (2) Google OAuth/Sheets 셋업 (3) 카드 발생주의 vs 출금 시점의 사용자 혼동 (4) workmanager Doze 백그라운드 제약. |
| **SUCCESS** | 5초 입력 / 가용 현금 항상 정확 / 30일 사용 / Sheets 3 시트 자동 누적. |
| **SCOPE** | M1 = Accounts + 4-type Tx + 잔액 자동갱신 + 홈 대시보드 + 3 시트 동기화. iOS/Store/멀티유저 OUT. |

---

## 1. User Intent Discovery

### 1.1 Core Problem

기존 가계부 앱들이 모든 돈의 흐름을 "지출/수입" 두 종류로만 분류해서:
- 신용카드 사용을 "지출"로 잡고 카드값 출금도 "지출"로 잡으면 **이중 계산**
- 주식 입금을 "지출"로 잡으면 자산이 줄어든 것처럼 보임 (실제로는 위치만 이동)
- 주식 평가금 변동이 가계부에 반영 안 됨 → 순자산 왜곡
- 결국 가계부와 실제 통장 잔액이 안 맞아서 신뢰가 깨지고 1~2개월 후 사용 중단

### 1.2 Target Users

| User Type | Usage Context | Key Need |
|-----------|---------------|----------|
| 본인 (단일 사용자) | Android 핸드폰 사이드로딩, 매일 1~5회 거래 입력 | 4-type 정확 분류 + 가용 현금 즉시 확인 + Sheets 누적 |

### 1.3 Success Criteria

- [ ] 앱 실행 → 거래 1건 저장까지 5초 이내 (단순 expense 기준)
- [ ] **순자산** = 모든 계좌 잔액 합 (입력한 거래만 반영, 공식과 정확히 일치)
- [ ] **가용 현금** = 현금성 자산 - 카드 미결제 잔액 (홈에서 즉시 확인)
- [ ] 출시 후 30일 연속 사용 (지속가능성)
- [ ] Google Sheets에 transactions / accounts / monthly_summary 3 시트가 30분 이내 최신 상태 유지

### 1.4 Constraints

| Constraint | Details | Impact |
|------------|---------|--------|
| 단일 디바이스/단일 사용자 | 본인 Android 1대만 | High — 멀티 동기화 불필요 |
| Android only | iOS 빌드/스토어 출시 모두 OUT | High |
| 사이드로딩 배포 | APK 수동 설치 | Medium |
| 본인 Google 계정 OAuth | 1 GCP 프로젝트 | Medium |
| **회계 정합성 우선** | 잔액 갱신은 거래와 동일 트랜잭션에서 atomic | High — Repository 설계 핵심 |

---

## 2. Alternatives Explored

### 2.1 Approach A: 복식부기 단순화 + 로컬-퍼스트 + 3-시트 미러 — Selected

| Aspect | Details |
|--------|---------|
| **Summary** | 4-type Tx + Accounts 자동잔액 → Drift, 3 시트 (append/snapshot/aggregate) → workmanager로 비동기 동기화 |
| **Pros** | 회계 정합성 보장, 5초 입력 유지, 오프라인 OK, Sheets에서 분석 자유 |
| **Cons** | 잔액 갱신 트랜잭션 일관성 코드 복잡, 3 시트 동기화 분기 |
| **Effort** | Medium-High |

### 2.2 Approach B: 단순 2-type (이전 v0.1)

| Aspect | Details |
|--------|---------|
| **Summary** | expense/income만, 카테고리 기반, 단일 시트 |
| **Pros** | 가장 단순 |
| **Cons** | 카드/자산 이동/평가금 표현 불가 → 1.1 핵심 문제 미해결 |
| **Effort** | Low |

### 2.3 Approach C: 풀 복식부기 (Ledger 모델)

| Aspect | Details |
|--------|---------|
| **Summary** | 모든 거래가 N개의 차변/대변 line items |
| **Pros** | 회계 정합성 최고 |
| **Cons** | 1인 가계부에 과한 학습 곡선 + UI 복잡 |
| **Effort** | High |

### 2.4 Decision Rationale

**Selected**: Approach A
**Reason**: 1.1 4가지 핵심 문제 (이중계산/자산이동/평가금/순자산왜곡) 모두 해결하면서, 4-type 모델은 사용자가 직관적으로 이해 가능 (Approach C 대비 학습 비용 1/5). 5초 입력 SLA도 깨지 않음.

---

## 3. YAGNI Review

### 3.1 Included (M1 Must-Have — 재정의)

- [ ] Accounts CRUD (6 type: cash/investment/savings/real_estate/credit_card/loan)
- [ ] Categories CRUD (변동/고정 구분, 기본 시드)
- [ ] Transactions CRUD (expense/income/transfer/valuation 4-type)
- [ ] 거래 시 잔액 자동 갱신 (atomic 트랜잭션)
- [ ] 거래 수정/삭제 시 잔액 undo + redo
- [ ] 홈 대시보드 7 지표 (순자산/현금성/투자/카드미결제/가용현금/월지출/월수입)
- [ ] Google OAuth 로그인
- [ ] **3 Sheets 자동 동기화** — transactions(append) + accounts(snapshot) + monthly_summary(aggregate)
- [ ] sync_queue 재시도 로직

### 3.2 Deferred (M2~M3)

| Feature | Reason | Revisit |
|---------|--------|---------|
| 카드별 보기 (이번 달 사용/다음 결제 예정) | 코어 안정 후 가치 큼 | M2 |
| 카테고리/고정비 분석 차트 | 1~2주 사용 데이터 누적 후 | M2 |
| 검색/필터 | 데이터 누적 후 효용 | M2 |
| 계좌 트리 시각화 (parent_account_id) | M1은 평면 리스트로 충분 | M2 |
| 반복 거래 템플릿 (월세/구독료) | 자동화는 코어 안정 후 | M3 |
| 월별/연도별 리포트 + 차트 시각화 | M3 | M3 |
| 종목별 시세 자동 갱신 | valuation 수동 입력으로 충분 | 보류 |
| SQLite 파일 자체의 Drive 백업 | Sheets 동기화로 핵심 백업 확보 | 보류 |

### 3.3 Removed (Won't Do)

| Feature | Reason |
|---------|--------|
| iOS/Web/Desktop | Android 단일 |
| Play Store | 사이드로딩 |
| 멀티 디바이스/멀티 유저 | 1인 |
| 영수증 사진 첨부 | 가벼움 우선 |
| 다중 통화 | KRW 단일 |
| 양방향 Sheets sync | mirror 채널 (앱 → Sheets만) |
| 음성 입력/위젯 | v2+ |
| 풀 복식부기 (line items) | 학습 곡선 |

---

## 4. Scope

### 4.1 In Scope (M1)

- [ ] Flutter Android 프로젝트 (`money_tracker_app/`) — 이미 스캐폴드 완료
- [ ] **5화면**: 홈 대시보드 / 입력 / 목록 / 계좌 관리 / 설정
- [ ] Drift SQLite 스키마 v2 (5 테이블: accounts, categories, transactions, sync_queue, kv_store)
- [ ] Account/Category/Transaction Repository + 잔액 자동갱신
- [ ] Google Sign-In + Sheets API v4 통합
- [ ] sync_queue 기반 백그라운드 동기화 (workmanager)
- [ ] 3 시트 자동 생성 + 동기화 (transactions append, accounts overwrite, monthly_summary upsert)

### 4.2 Out of Scope (M1)

- iOS / Web / Desktop 빌드
- Play Store 배포
- 카드별 상세 보기, 카테고리 분석 차트, 계좌 트리 UI
- 반복 거래, 시세 자동 갱신, SQLite 자체 백업
- 양방향 Sheets sync, 멀티 디바이스/유저

---

## 5. Requirements

### 5.1 Functional Requirements

| ID | Requirement | Priority | Status |
|----|-------------|----------|--------|
| FR-01 | Account CRUD: 사용자는 계좌를 6 type 중 하나로 등록·수정·비활성화할 수 있다 | High | Pending |
| FR-02 | Category CRUD: 사용자는 expense/income 카테고리에 is_fixed 플래그로 등록할 수 있다 | High | Pending |
| FR-03 | 사용자는 expense/income/transfer/valuation 4종 거래를 입력할 수 있다 | High | Pending |
| FR-04 | 거래 입력 시 관련 계좌 잔액이 동일 트랜잭션 내에서 자동 갱신된다 | High | Pending |
| FR-05 | 거래 수정 시 이전 잔액 효과 undo + 새 효과 적용 (atomic) | High | Pending |
| FR-06 | 거래 삭제(soft) 시 잔액 효과 undo (atomic) | High | Pending |
| FR-07 | 사용자는 거래 목록을 발생일 최신순으로 조회할 수 있다 (계좌별·카테고리별 필터는 M2) | High | Pending |
| FR-08 | 홈 대시보드에 순자산/현금성/투자/카드미결제/가용현금/월지출/월수입 7 지표가 실시간 반영된다 | High | Pending |
| FR-09 | Google OAuth 로그인 후 본인 계정에 시트가 없으면 자동 생성한다 | High | Pending |
| FR-10 | 거래 저장 시 sync_queue에 enqueue, 백그라운드 워커가 transactions 시트에 append | High | Pending |
| FR-11 | accounts 시트는 매 동기화 cycle마다 전체 덮어쓰기 (스냅샷 전략) | High | Pending |
| FR-12 | monthly_summary 시트는 앱이 미리 집계해서 push (year_month/income/expense/net/net_worth_end) | High | Pending |
| FR-13 | 동기화 실패 시 큐에 보관 후 다음 cycle에 재시도 | High | Pending |
| FR-14 | 거래 수정/삭제는 transactions 시트에서 tx_id로 매칭해 update/clear | Medium | Pending |
| FR-15 | 설정 화면에 동기화 상태(미동기화 N건, 마지막 성공 시각)와 시트 링크 표시 | Medium | Pending |
| FR-16 | 입력 화면은 type 선택에 따라 동적으로 폼 변경 (expense=from+category, income=to+category, transfer=from+to, valuation=to만) | High | Pending |
| FR-17 | 카드 거래 입력은 발생주의 안내 (출금일 ≠ 사용일, "카드값은 transfer로") | Medium | Pending |
| FR-18 | 잔액 무결성: 모든 거래 합계로 재계산했을 때 현재 잔액과 일치 (앱 시작 시 1회 검증) | Medium | Pending |

### 5.2 Non-Functional Requirements

| Category | Criteria | Measurement |
|----------|----------|-------------|
| 성능 (입력) | expense 1건 저장 ≤ 5초 (콜드 스타트 포함) | stopwatch |
| 성능 (대시보드) | 홈 진입 ≤ 200ms (1만 건 거래 가정) | Drift reactive query + caching |
| 성능 (UI 반응) | 저장 후 목록 갱신 ≤ 100ms | reactive query |
| 신뢰성 (동기화) | 네트워크 회복 후 미동기화 건수 0으로 수렴 | 설정 화면 카운터 |
| 신뢰성 (잔액 무결성) | 거래 100건 임의 입력 후 잔액 재계산 결과 일치 (FR-18) | 단위 테스트 |
| 보안 | OAuth 토큰은 flutter_secure_storage 보관 | 코드 리뷰 |
| 오프라인 | 비행기 모드에서 모든 CRUD + 대시보드 동작 | 수동 테스트 |

---

## 6. Success Criteria (Definition of Done)

### 6.1 M1 DoD

- [ ] FR-01~FR-18 구현
- [ ] APK 빌드 성공, 본인 핸드폰 설치
- [ ] 시드 계좌 3종(현금성·투자·카드) 등록 후 5종 거래 입력 → 모든 잔액 정확
- [ ] 비행기 모드 입력 5건 → 복구 후 30분 내 3 시트 모두 반영
- [ ] 홈 대시보드 7 지표 모두 표시 + 거래 입력 즉시 반영

### 6.2 Quality Criteria

- [ ] flutter analyze 0 issues
- [ ] Repository/Sync 로직 단위 테스트 커버리지 ≥ 60%
- [ ] **잔액 무결성 invariant 테스트** (FR-04, FR-05, FR-06, FR-18)
- [ ] Drift 마이그레이션 스크립트 동작 (M2 진입 대비 v1→v2 패턴 확립)

---

## 7. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 잔액 갱신 트랜잭션 일관성 깨짐 | High | Medium | 모든 잔액 갱신은 Drift transaction 내부 + delta 컬럼으로 undo 가능 + 무결성 테스트 |
| 사용자가 카드 거래를 transfer/expense 잘못 분류 | Medium | High | 입력 화면에 발생주의 가이드 + 카드 계좌 선택 시 안내 텍스트 |
| Google OAuth/Sheets 셋업 복잡 | High | Medium | M1 첫 작업으로 GCP 셋업 + sheets_client 단독 sanity check |
| 3 시트 동기화 로직 복잡도 (특히 monthly_summary 재계산) | Medium | Medium | accounts는 단순 덮어쓰기, monthly_summary는 마지막 12개월만 push |
| workmanager Doze 제약 | Medium | High | foreground 진입 시 즉시 1회 flush 트리거 병행 |
| Drift 스키마 변경 (v1→v2) 마이그레이션 | Medium | Low | M1 시작 시점에 v2 한번에 확정. M2부터 표준화된 마이그레이션 |
| 잔액 음수 의도(부채) vs 사용자 실수 음수 구분 모호 | Low | Medium | UI에서 type=credit_card/loan일 때 "부채는 음수로 누적됩니다" 안내 |

---

## 8. Architecture Considerations

### 8.1 Project Level Selection

| Level | Selected |
|-------|:--------:|
| **Dynamic** (Feature-based modules + 외부 통합) | ✅ |

### 8.2 Key Decisions (v0.2 변경분 강조)

| Decision | Selected | Rationale |
|----------|----------|-----------|
| 회계 모델 | **4-type 단순화 (Approach A)** | 1인 가계부의 회계 정합성 ↔ 학습 비용 균형 |
| 잔액 관리 | **delta 컬럼 + atomic transaction** | edit/delete 시 undo 단순, 무결성 보장 |
| 시트 전략 | **3 시트 (append/snapshot/aggregate)** | transactions는 append-only로 데이터 보존, accounts는 매번 덮어 항상 최신, monthly_summary는 분석 즉시 가능 |
| 로컬 DB | **Drift** | 변경 없음 |
| 상태관리 | **Riverpod 2.x** | 변경 없음 |
| 백그라운드 | **workmanager + foreground 즉시 트리거** | 변경 없음 |

### 8.3 Component Overview (v0.2)

```
money_tracker_app/lib/
├── main.dart
├── app/                 # 셸, 라우팅, 테마, workmanager 등록
├── features/
│   ├── accounts/        # 신규 — Account domain/data/ui
│   ├── categories/      # is_fixed 추가
│   ├── transactions/    # 4-type + balance update Repository
│   ├── sync/            # 3-시트 SyncService
│   ├── auth/            # GoogleAuthService
│   ├── dashboard/       # 신규 — 7 지표 집계 + HomeScreen
│   └── settings/
├── core/
│   ├── db/              # tables.dart (5 테이블), app_database.dart
│   └── secure/
└── infrastructure/
    └── sheets/          # SheetsClient (3-시트 op)
```

### 8.4 Data Flow (잔액 갱신 + 3-시트 동기화)

#### 거래 입력 + 잔액 갱신 (atomic)

```
User submits Tx draft
  → TransactionRepository.add(draft)
       db.transaction {
         compute deltas (expense: from-, income: to+, transfer: from-/to+, valuation: to=abs - prev)
         tx insert with from_delta, to_delta
         accounts update (apply deltas)
         sync_queue enqueue(localId, insert)
       }
  → reactive query → ListScreen + HomeDashboard 즉시 갱신
  → (≤5s 완료)
```

#### 3-시트 동기화 (배치)

```
SyncService.flush():
  1. transactions: queue 처리 (append/update-by-tx_id/clear)
  2. accounts: 모든 계좌 read → values.update("accounts!A:F", overwrite)
  3. monthly_summary: 최근 12개월 집계 → values.update("monthly_summary!A:E", overwrite)
```

### 8.5 Domain Invariants (Repository 단에서 강제)

1. **잔액 무결성**: `account.balance == sum(deltas of all non-deleted tx affecting account)` — FR-18
2. **type별 필드 정합성**:
   - `expense`: from_account_id + category_id NOT NULL, to NULL, category.kind='expense'
   - `income`: to_account_id + category_id NOT NULL, from NULL, category.kind='income'
   - `transfer`: from + to NOT NULL, category NULL, from ≠ to
   - `valuation`: to NOT NULL, from + category NULL
3. **amount > 0** 항상 (sign은 type/방향이 결정)
4. **카테고리 kind 일치**: expense Tx → expense category만 / income Tx → income category만

---

## 9. Convention Prerequisites

- Flutter / Dart 표준 lint (flutter_lints) — `prefer_relative_imports`, `require_trailing_commas`, `sort_constructors_first`
- 폴더 구조: `features/{feature}/{ui,domain,data}` (sync는 `+service/`)
- Riverpod provider 네이밍: `xxxProvider`, `xxxNotifier`
- Drift 테이블 클래스: `Accounts`, `Transactions`, dao: `AccountsDao`, `TransactionsDao`
- 한국어 UI 문자열 const string으로 모음 (i18n M3)
- **잔액 변경은 반드시 Drift transaction 내부에서만**

---

## 10. Milestones (v0.2 재정의)

| MS | 범위 | 핵심 작업 | 예상 |
|----|------|-----------|------|
| **M1 코어** | Accounts + 4-type Tx + 잔액 자동갱신 + 홈 대시보드 + **3 시트 동기화** | 스키마 v2, 잔액 invariant, AccountsDao, 5화면, 3-시트 SyncService | 3주 |
| **M2 분석** | 카테고리/고정비 분석, 카드별 보기, 계좌 트리 UI, 검색/필터 | 집계 쿼리, parent_account_id 트리, 필터 UI | 1.5주 |
| **M3 자동화** | 반복 거래 + 월별/연도별 리포트 + 차트 | 반복 규칙, 차트 라이브러리, 리포트 화면 | 2주 |

> M1 출시 후 본인 1~2주 사용 → M2 우선순위 재검토.

---

## 11. Next Steps

1. [x] ~~`/pdca plan` (v0.1)~~ → `/pdca plan v0.2` 갱신 ✅
2. [x] ~~`/pdca design` (v0.1)~~ → `/pdca design v0.2` 갱신 ⏳ (다음)
3. [ ] GCP 프로젝트 + OAuth 클라이언트 + Sheets API enable (사전 작업)
4. [ ] Module 1 재구현 (db-foundation v2)
5. [ ] Module 2 재구현 (transactions-data v2 + 잔액 자동갱신)
6. [ ] Module 3+ (sheets-infra → sync-service → dashboard → ui-shell → input/list/settings → android-build)
7. [ ] M1 Gap Analysis → 90%+ 도달 시 M1 출시 + 본인 사용

---

## Appendix A: detail.md Summary

`.claude/detail.md`에서 정의된 핵심 개념 요약 (이 Plan v0.2의 source of truth):

- **4-type 거래 모델**: expense / income / transfer / valuation
- **Accounts 통합 관리**: 모든 자산·부채를 단일 테이블, 6 type
- **카드 발생주의**: 사용 시점 = expense, 출금 시점 = transfer (별개 거래)
- **잔액 자동 갱신**: 거래 시 type별 공식으로 from/to 계좌 +/-
- **valuation 특수 처리**: 절대값으로 잔액 덮어쓰기 (시세 갱신용)
- **3-시트 Sheets 구성**: transactions(append) / accounts(snapshot) / monthly_summary(aggregate)
- **MVP 정의**: Accounts CRUD + Transactions CRUD + 잔액 갱신 + 기본 대시보드 (Plan v0.2는 여기에 Sheets 동기화도 M1로 포함)

---

## Appendix B: Brainstorming Log

| Phase | Question | Answer | Decision |
|-------|----------|--------|----------|
| Intent | 기존 가계부 앱의 가장 큰 불만 | 카드/자산이동/평가금 처리 잘못으로 신뢰 깨짐 | 4-type 모델 채택 |
| Alternatives | 회계 모델 깊이 | 단순 2-type vs 4-type 단순화 vs 풀 복식부기 | **4-type 단순화** (회계정합성 ↔ 학습비용 균형) |
| YAGNI | M1 범위 | 입력+조회+동기화 vs MVP+대시보드+동기화 | **MVP+대시보드+3시트 모두 M1** (사용자 결정) |
| Scope | Sheets 시트 수 | 단일 vs 3 시트 | **3 시트** — accounts/monthly까지 자동 동기화 |
| Constraint | 잔액 갱신 일관성 | 트리거 vs application | **application + delta 컬럼** — Dart에서 atomic 트랜잭션 |

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 0.1 | 2026-04-28 | Initial draft (Plan Plus, 단순 expense/income 모델) | kyk@hunik.kr |
| **0.2** | **2026-04-28** | **`.claude/detail.md` 반영. 4-type Tx + Accounts + 카드 발생주의 + 잔액 자동갱신 + 홈 대시보드 7지표 + 3-시트 Sheets. M1 재정의 (Sheets 포함).** | **kyk@hunik.kr** |
