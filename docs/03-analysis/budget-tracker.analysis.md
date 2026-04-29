---
template: analysis
version: 1.0
feature: budget-tracker
date: 2026-04-28
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.2.0"
level: Dynamic
basePlan: docs/01-plan/features/budget-tracker.plan.md
baseDesign: docs/02-design/features/budget-tracker.design.md
overallMatchRate: 92
verdict: above-threshold-with-2-important-gaps
---

# Budget Tracker — Gap Analysis (Module 1-7 누적)

> **Verdict**: Match Rate **92%** (static-only 공식). 90% 임계 초과. Critical 0건, Important 2건. Module-8 진행 가능하나 P0/P1 수정 권장.

---

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 회계 정합성 (4-type) + 데이터 주권 (Sheets) + 가용 현금 가시성 |
| **WHO** | 본인 1인 / Android / Google 1 계정 |
| **RISK** | 잔액 트랜잭션 일관성 / OAuth 셋업 / Doze |
| **SUCCESS** | 5초 입력 / 가용 현금 정확 / 30일 사용 / 3 시트 자동 누적 |
| **SCOPE** | M1 = Module 1-8 (Module-8 미완) |

---

## 1. Match Rate Scores

| 축 | 점수 | 가중치 | 기여 |
|----|----:|:----:|----:|
| Structural Match | 97% | ×0.2 | 19.4 |
| Functional Depth | 89% | ×0.4 | 35.6 |
| Domain Contract | 95% | ×0.4 | 38.0 |
| **Overall** | **92%** | | **93.0** |

**공식 (static-only, mobile)**: HTTP 서버 없는 mobile 프로젝트 → L1/L2/L3 runtime 미실행. Design §8.2 통합 테스트는 Module-4에서 deferred, 디바이스 sanity check로 대체.

```
Overall = (Structural × 0.2) + (Functional × 0.4) + (Contract × 0.4)
```

---

## 2. FR Matrix (18)

| FR | 상태 | 증거 |
|----|:----:|------|
| FR-01 Account CRUD | ✅ | `account_repository.dart` + `accounts_screen.dart` + `account_form_sheet.dart` |
| FR-02 Category CRUD + is_fixed | ✅ | `tables.dart` isFixed; `category_seed.dart` 17개 시드 |
| FR-03 4-type Tx 입력 | ✅ | `transaction.dart` enum + `input_screen.dart` SegmentedButton |
| FR-04 add atomic balance update | ✅ | `transaction_repository.dart:46-84` `_db.transaction(...)` |
| **FR-05 update with undo+redo** | **⚠️ Partial** | Repository.update 완성됐으나 UI 진입 경로 없음 (List에 edit 제스처 미구현) |
| FR-06 soft-delete with undo | ✅ | `transaction_repository.dart:139-154`; List dismiss |
| FR-07 List by occurred_at desc | ✅ | `transactions_dao.dart` orderBy desc |
| FR-08 Dashboard 7 metrics | ✅ | `dashboard_metrics.dart` 7 fields; `home_screen.dart` |
| FR-09 spreadsheet 자동 생성 | ✅ | `sync_service.dart` `_ensureSpreadsheet` + `ensureSheet` x3 |
| FR-10 tx queue → transactions append | ✅ | `_processInsert` |
| FR-11 accounts snapshot overwrite | ✅ | `_pushAccountsSnapshot` |
| FR-12 monthly_summary aggregate push | ✅ | `_pushMonthlySummary` + `MonthlyAggregator.compute(months: 12)` |
| FR-13 동기화 실패 시 재시도 | ✅ | `recordAttempt` + `_bumpFailureCount` |
| FR-14 update/delete tx_id 매칭 | ✅ | `findRowByLocalId` → updateRow/clearRange (degrade to insert if missing) |
| FR-15 Settings 동기화 상태 + Sheets 링크 | ✅ | `settings_screen.dart` |
| FR-16 type-specific 동적 폼 | ✅ | `input_screen.dart` `_fieldsForType` |
| FR-17 카드 발생주의 안내 | ⚠️ Partial | expense+credit_card에만 표시. transfer-to-credit_card 안내 없음 (minor) |
| **FR-18 잔액 무결성 검증** | **❌ Not Met** | Settings 버튼 없음, app-start 검증 없음 |

**합계**: 16 ✅ / 2 ⚠️ / 1 ❌ / 0 🚫

---

## 3. Decision Record Verification

| 결정 | 상태 | 증거 |
|------|:----:|------|
| [Plan] Approach A — 4-type + 로컬-퍼스트 + 3-sheet | ✅ | TxType 4값, SQLite, SyncService 3 시트 |
| [Design] Option C — Repository + 별도 SyncService | ✅ | `transaction_repository.dart` ⊄ sheets_client |
| [Design] Drift INT (epoch) DateTime | ✅ | `build.yaml` 없음 → default INT; customStatement는 `strftime('%s','now')` |
| [Design] google_sign_in + drive.file scope | ✅ | `sheet_layout.dart:68-71` |
| [Design] workmanager 15min periodic | ✅ | `main.dart:33-39` |

**5/5 followed**.

---

## 4. Domain Contract Match (Invariants)

| 인바리언트 | 상태 |
|-----------|:----:|
| 잔액 변경은 AccountsDao만 | ✅ Repository에 balance setter 없음, `updateMeta`는 `assert(!patch.balance.present)` |
| Sheets 호출은 SyncService만 | ✅ Repository에 sheets_client import 없음 |
| NewTransaction.validate 8가지 위반 케이스 | ✅ + 테스트 7개 (1개 미테스트 — minor) |
| Atomic balance update wrap in db.transaction | ✅ add/update/delete 모두 |
| from_delta/to_delta + invert on undo | ✅ `_applyDeltas(invert: true)` |
| 3-sheet 경계 (append/overwrite/aggregate) | ✅ try/catch 분리 |
| Drift DateTime INT 모드 일관성 | ✅ recent fix 검증됨 |

---

## 5. Strategic Alignment

| Plan §1.1 핵심 문제 | M1 해결 증거 |
|---|---|
| 카드 이중 계산 | InputScreen 카드 안내 + Dashboard `creditCardBalance` 별도 표시 |
| 자산 이동 잘못 잡힘 | `TxType.transfer` from+to NOT NULL + category NULL 인바리언트 |
| 평가금 미반영 | `TxType.valuation` prevBalance 읽고 signed delta 계산 |
| 순자산 왜곡 | `DashboardMetrics.netWorth = sum(active accounts.balance)` |

**가용 현금** (`cashAssets + creditCardBalance`) → HomeScreen 최상단 강조 카드로 노출. Plan §1.3 핵심 가치 직접 충족.

**Sheets 데이터 주권** → on-device sanity check 5단계 + 3 시트 모두 자동 누적 검증 (이전 세션 로그).

---

## 6. Gap List (severity-ranked)

| # | Severity | 갭 | 위치 | 권장 수정 | 추정 |
|---|:--------:|----|------|----------|:----:|
| 1 | **Important** | FR-18 잔액 무결성 검증 부재 | `settings_screen.dart` (위젯 없음) | `BalanceReconciler.findDrifts()` → Settings 버튼 wire | ~30분 |
| 2 | **Important** | FR-05 거래 수정 UI 부재 (Repository는 완성) | `list_screen.dart` (onTap 없음) | _TxTile에 onTap → InputScreen edit 모드 | ~45분 |
| 3 | Minor | FR-17 transfer-to-card 안내 없음 | `input_screen.dart:182-188` | `type == transfer && to?.type == creditCard` 분기 추가 | ~10분 |
| 4 | Minor | MonthlySummary.net 컬럼 vs getter 불일치 | `monthly_aggregator.dart:23` | Design §4.7 derived로 표기 변경 | ~5분 |
| 5 | Minor | 앱 버전 스트링 v0.1.0 (Plan은 0.2.0) | `settings_screen.dart:253` | `v0.2.0` 로 수정 | ~2분 |
| 6 | Minor | account_seed.dart 미생성 (Design "(선택)" 표기) | n/a | Module-8 결정 사항 | n/a |

**Critical 0건**.

---

## 7. Test Coverage Spot-Check

| 영역 | 커버 |
|------|:----:|
| DeltaCalculator (15 테스트) | ✅ 100% |
| NewTransaction.validate (12 테스트) | ✅ 7/8 위반 케이스 |
| MonthlyAggregator (11 테스트) | ✅ |
| DashboardMetrics.compute (6 테스트) | ✅ |
| SheetLayout (9 테스트) | ✅ |
| SyncEnqueuer fake (3 테스트) | ✅ |
| **TransactionRepository 통합** | ❌ Module-4에서 deferred — sqlite native binary 셋업 미해결 |
| **SyncService.flush 통합** | ❌ Module-4에서 deferred — Sheets API mock 필요 |

Plan §6.2 Quality Criteria "Repository/Sync 60%+ 커버리지" — 순수 함수는 100%지만 atomic balance flow는 자동 테스트 미커버. 디바이스 sanity check가 그 자리를 메우고 있음.

---

## 8. Recommendations (Module-8 진입 전)

| 우선순위 | 액션 | 비용 | 가치 |
|:--------:|------|:----:|------|
| **P0** | FR-18 reconciler + Settings 버튼 | 30분 | 유일한 outright miss; Plan §6.2 DoD에 명시 |
| **P1** | 거래 수정 UI wire (Gap #2) | 45분 | High 우선순위 FR-05; 백엔드는 완성 |
| **P2** | TransactionRepository in-memory Drift 통합 테스트 5개 | 1시간 | Quality Criteria 60%+ 충족; CI 회귀 방지 |
| P3 | Gap #3, #5 (minor UX/version) | 15분 | 선택 |
| P3 | Design §4.7 net 표기 (Gap #4) | 5분 | 문서 정합성 |

**총 합계 (P0+P1+P2)**: ~2시간 15분. 아키텍처 변경 없음.

---

## 9. Verdict

Plan v2.0 + Design v2.0의 충실한 구현. 92% Match Rate는 강한 정합성을 반영.

**사용자 결정**: P0+P1 수정 후 보고서 (옵션 A) 채택.

---

## 10. Act-1 Iteration 결과 (2026-04-28 추가)

### 10.1 적용된 수정

| 갭 | 수정 내용 | 파일 | LOC |
|----|----------|------|----:|
| FR-18 | `BalanceReconciler` 구현 — kv_store에 시작 잔액 기록 + 잔액 무결성 검증 + Settings UI 섹션. 기존 계좌(v0.2 이전)는 backfill로 baseline 설정. | `lib/features/accounts/data/balance_reconciler.dart` (신규) + `account_repository.dart` + `settings_screen.dart` + `app/providers.dart` + `test/balance_drift_test.dart` (신규) | ~330 |
| FR-05 | `InputScreen`에 `existing` 파라미터 추가 → edit 모드. ListScreen 행 onTap → `Navigator.push(InputScreen(existing: tx))` | `input_screen.dart` + `list_screen.dart` | ~80 |
| Minor | 앱 버전 v0.1.0 → v0.2.0 | `settings_screen.dart` | 1 |

### 10.2 Post-iteration Match Rate (수동 추정)

| 축 | Before | After | 변동 |
|----|------:|------:|----:|
| Structural | 97% | 97% | — |
| Functional | 89% (16/18) | **94%** (17/18 + 1 ⚠️ minor) | +5% |
| Domain Contract | 95% | 95% | — |
| **Overall** | **92%** | **~95%** | **+3%** |

남은 ⚠️ 1건: FR-17 transfer-to-credit_card 안내 (M2 minor).

### 10.3 후속 검증

- `flutter analyze`: 0 issues
- `flutter test`: **63/63 통과** (이전 56 + BalanceDrift 7 신규)
- Debug APK 빌드 성공 (37.5초, 변경 작아 incremental)

### 10.4 잔여 deferred 항목

| 항목 | Priority | 처리 |
|------|:--------:|------|
| FR-17 transfer-to-credit_card 안내 | Minor | M2 |
| TransactionRepository in-memory Drift 통합 테스트 | P2 | M2 (sqlite native binary 셋업과 함께) |
| MonthlySummary.net 컬럼/getter 표기 정합 | Minor | Design §4.7 다음 개정 시 |
| account_seed.dart | Optional | Module-8 또는 M2 |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-28 | Initial gap analysis after Module 1-7 (M1 functional). Match Rate 92%. |
| 1.1 | 2026-04-28 | Act-1 iteration 추가 — FR-18 + FR-05 구현 완료. Match Rate ~95%. |
