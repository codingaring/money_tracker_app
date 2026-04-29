---
template: plan
version: 1.0
feature: budget-tracker-m2
cycle: M2
date: 2026-04-28
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.3.0"
level: Dynamic
basePlan: docs/01-plan/features/budget-tracker.plan.md
baseReport: docs/04-report/budget-tracker.report.md
---

# Personal Budget Tracker — M2 Cycle Planning

> **Summary**: M1으로 1-2주 사용 후 누적된 데이터로 "내 돈을 어떻게 쓰고 있는지" 분석할 수 있는 도구. 카드별 결제 예측 + 카테고리 차트 + 검색/필터 + 계좌 트리 시각화 추가.
>
> **Cycle**: M2 (M1 완료 후속)
> **Status**: Draft
> **Method**: Plan (M1에서 도메인 모델은 이미 확정)

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | M1은 입력·기록 도구. 그런데 누적된 데이터를 "어디에 얼마 썼는지" / "다음 카드값이 얼마 나갈지" / "특정 거래를 다시 찾기" 같은 분석·탐색 작업은 Sheets로 직접 가야 가능. 앱 안에서 닫혀야 매일 사용 가치 유지. |
| **Solution** | 5개 분석 기능 추가 — 카드별 결제 예정 화면, 새 "분석" 탭 (카테고리 도너츠 + 고정비 추이), List 탭 SearchBar + Filter, 계좌 트리(부모-자식) UI, transfer-to-card 발생주의 안내. fl_chart 도입. Repository 통합 테스트로 품질 부채 청산. |
| **Function/UX Effect** | 5탭 → 6탭 (분석 추가). AccountsScreen 행 탭 → 카드 상세(이번 달 누적/결제 예정일/최근). 분석 탭 도너츠로 한 화면에 카테고리 비중. 내역 탭 SearchBar + 칩 필터로 어떤 거래든 즉시 탐색. |
| **Core Value** | M1 = 입력 + 보관. **M2 = 이해 + 예측**. 본인이 매월 어느 카테고리에서 새고, 다음 카드값이 언제·얼마 나갈지 미리 알고 대응. 가계부의 진짜 가치 (다음 행동 결정에 도움)를 닫음. |

---

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 누적된 데이터로 본인 소비 패턴을 이해 + 다음 카드 결제 예측 → 행동 결정에 도움 |
| **WHO** | 본인 1인 (M1과 동일). M1을 1-2주 사용해 데이터가 누적된 상태 |
| **RISK** | (1) 6탭 NavigationBar 좁아짐 (2) 카드 결제일 정보 부재 — 스키마 v2→v3 필요 (3) 차트 학습 곡선 + APK 크기 증가 (4) 검색 성능 (10K 거래 가정) |
| **SUCCESS** | 카드 결제 예정 정확 / 카테고리 분석 매월 1회 사용 / 검색 결과 ≤ 100ms / 통합 테스트 60% 커버리지 |
| **SCOPE** | 카드 상세 + 분석 탭 + 검색·필터 + 계좌 트리 + Repo 통합 테스트. 반복 거래·리포트는 M3. |

---

## 1. User Intent Discovery

### 1.1 Core Problem (M1 사용 후 발견)

M1은 거래 기록을 잘 보관한다. **그러나 보관된 데이터가 행동 결정에 즉시 쓰이지 않는다**:

- "다음 달 카드값 얼마 나가지?" → 현재 카드 잔액 절댓값을 봐야 하지만, 결제일까지 며칠 남았는지는 모름
- "지난 달 식비 얼마 썼지?" → ListScreen에서 스크롤해서 추산 (정확하지 않음)
- "월급 작년 내역 찾기" → memo 검색이 안 됨
- "고정비가 너무 많은 거 아냐?" → 고정비 합계 어디서도 안 보임
- "신한 통장 + 삼성카드는 한 묶음" → AccountsScreen에서 평면 리스트로 분리 표시

→ 결국 분석은 Google Sheets에 가서 피봇으로 직접 만들게 되고, 앱은 입력 전용으로 격하됨.

### 1.2 Target Users

| User Type | Usage Context | Key Need |
|-----------|---------------|----------|
| 본인 (M1 사용자, 1-2주 데이터 누적) | 매주 1회 카드 결제 예측 + 매월 1회 카테고리 분석 + 수시 검색 | 분석을 앱 안에서 끝내기 |

### 1.3 Success Criteria

- [ ] **카드 결제 예정**: 다음 결제일까지 D-day + 예상 금액 정확히 표시
- [ ] **카테고리 분석**: 월별 도너츠로 카테고리 비중 + 고정비/변동비 분리
- [ ] **검색 응답**: 키워드 입력 후 결과 표시 ≤ 100ms (1만 건 가정)
- [ ] **계좌 트리**: AccountsScreen에서 카드↔통장 부모자식 관계 시각화
- [ ] **품질**: TransactionRepository 통합 테스트 5건 통과 (Plan §6.2 충족)

### 1.4 Constraints

| Constraint | Details | Impact |
|------------|---------|--------|
| M1 도메인 모델 유지 | 4-type Tx + Accounts + 3-시트 동기화 그대로 | High — 기존 코드 재사용 |
| Schema 마이그레이션 v2→v3 | accounts.due_day 컬럼 추가 (credit_card 결제일) | High — 첫 마이그레이션 작성 표준화 |
| 6탭 한계 | NavigationBar 6 destination — 더 늘리지 말 것 | Medium |
| APK 크기 ≤ 30MB | fl_chart 추가로 ~3MB 증가 예상 | Low |

---

## 2. Alternatives Briefly Considered

### 2.1 카드 결제 예정 위치

| 옵션 | 장단점 | 결정 |
|------|--------|------|
| **계좌 탭 → 카드 상세 (선택)** | 자연스러운 drill-down + 5탭 유지 | ✅ |
| 새 "카드" 탭 | 가시성 ↑ 그러나 탭 과밀 | ❌ |
| Home 카드 형태 | 가장 빠른 시야 그러나 Home 고밀도 | ❌ |

### 2.2 분석 화면 위치

| 옵션 | 장단점 | 결정 |
|------|--------|------|
| **새 "분석" 탭 (선택)** | 명확한 분리, 6탭째 | ✅ |
| Home 확장 | 한눈에 보기 좋으나 Home 무거움 | ❌ |
| List 상단 토글 | 공간 효율 그러나 차트가 하위 메뉴화 | ❌ |

### 2.3 차트 라이브러리

**fl_chart 채택**: Flutter 생태계 점유율 1위 + MIT + 도너츠/라인/막대 모두 지원 + 경량.

### 2.4 검색 진입점

**ListScreen 상단 SearchBar (선택)**: List 탭이 거래 탐색의 자연스러운 entry. 별도 검색 화면 push는 navigation 깊이만 증가.

---

## 3. YAGNI Review

### 3.1 Included (M2 Must-Have)

- [ ] 카드 상세 화면 (AccountsScreen 카드 행 → push)
  - 이번 달 누적 사용액
  - 다음 결제 예정일 (D-day) + 예상 금액
  - 최근 사용 내역 (해당 카드 거래 10건)
- [ ] 새 "분석" 탭 (6탭째)
  - 월 카테고리 도너츠 (expense)
  - 고정비 vs 변동비 라인 차트 (최근 6개월)
- [ ] ListScreen SearchBar + Filter
  - keyword (memo) 검색
  - 칩 필터: 기간 / 계좌 / 카테고리 / type
- [ ] 계좌 트리 UI
  - AccountsScreen에 parent-child 들여쓰기 표시
  - AccountFormSheet에 부모 계좌 선택 dropdown
- [ ] transfer-to-credit_card 안내 (FR-17 보완)
- [ ] TransactionRepository in-memory Drift 통합 테스트 5건
- [ ] sqlite3 dev_dep 추가 + flutter_test_setup
- [ ] **Drift 스키마 v2 → v3 마이그레이션** (`accounts.due_day` 컬럼)

### 3.2 Deferred (M3)

| Feature | Reason | Revisit |
|---------|--------|---------|
| 반복 거래 템플릿 | 자동화는 분석 위에 올라타야 패턴 인식 가능 | M3 |
| 월별/연도별 리포트 (Sheets처럼) | 도너츠/추이 차트로 충분 (M2 사용 후 재검토) | M3 |
| 종목별 시세 자동 갱신 | 보류 — 수동 valuation으로 충분 |
| 예산 설정 + 초과 경고 | 카테고리 분석 데이터 1-2개월 누적 후 의미 | M3 또는 M4 |
| 음성 입력 / 위젯 | v2+ |

### 3.3 Removed (Won't Do)

| Feature | Reason |
|---------|--------|
| 카드별 보기를 별도 탭 | 6탭 한계 + 계좌 drill-down으로 충분 |
| 검색 전용 화면 | List 상단 SearchBar로 충분 |
| 차트 색상 커스터마이징 | M1 기본 테마로 |

---

## 4. Scope

### 4.1 In Scope (M2)

- 카드 상세 화면 (`features/accounts/ui/card_detail_screen.dart`)
- 분석 탭 + 카테고리 도너츠 + 고정비/변동비 라인 (`features/analytics/ui/analytics_screen.dart` + `data/analytics_repository.dart`)
- List SearchBar + 칩 필터 (`features/transactions/ui/search_bar.dart` + `transactions_dao.dart` 검색 메서드 추가)
- 계좌 트리 UI (`accounts_screen.dart` 수정 + AccountFormSheet 부모 선택 추가)
- transfer-to-credit_card 안내 (`input_screen.dart` 보완)
- Repository 통합 테스트 5건 (`test/integration/transaction_repository_test.dart`)
- Drift 스키마 v3 마이그레이션 + due_day 컬럼

### 4.2 Out of Scope (M2)

- 반복 거래, 월별 리포트, 시세 자동, 예산 (M3)
- 음성/위젯 (v2+)
- 카테고리 차트 색상 커스터마이즈

---

## 5. Requirements

### 5.1 Functional Requirements (M2 신규)

| ID | Requirement | Priority | Status |
|----|-------------|:--------:|:------:|
| FR-19 | AccountsScreen에서 credit_card 행 탭 → 카드 상세 화면 push | High | Pending |
| FR-20 | 카드 상세에 이번 달 누적 사용액, 다음 결제일 D-day, 예상 결제액, 최근 사용 내역 10건 표시 | High | Pending |
| FR-21 | accounts 테이블에 `due_day INTEGER NULLABLE (1-31)` 추가 + Drift 마이그레이션 v2→v3 작성 | High | Pending |
| FR-22 | AccountFormSheet에서 credit_card 타입 선택 시 결제일 입력 필드 동적 노출 | High | Pending |
| FR-23 | 새 "분석" 탭 추가 (NavigationBar 6탭째) | High | Pending |
| FR-24 | 분석 탭에 월별 카테고리 도너츠 (expense, fl_chart) — 월 선택 가능 | High | Pending |
| FR-25 | 분석 탭에 최근 6개월 고정비 vs 변동비 라인 차트 | High | Pending |
| FR-26 | ListScreen 상단에 SearchBar + 칩 필터 (기간 / 계좌 / 카테고리 / type) | High | Pending |
| FR-27 | TransactionsDao에 검색 메서드 추가: keyword + 필터 조합 쿼리 | High | Pending |
| FR-28 | AccountsScreen에 부모-자식 트리 들여쓰기 표시 | Medium | Pending |
| FR-29 | AccountFormSheet에 부모 계좌 선택 dropdown 추가 | Medium | Pending |
| FR-30 | transfer 거래에서 to_account 가 credit_card이면 "카드값 결제 맞나요?" 안내 표시 | Low (FR-17 보완) | Pending |
| FR-31 | TransactionRepository 통합 테스트 5건 (in-memory Drift): add expense / add transfer / update / delete / valuation | Medium | Pending |
| FR-32 | accounts/transactions 시트 `due_day` 컬럼 추가 (M2 schema sync) | Low | Pending |

### 5.2 Non-Functional Requirements

| Category | Criteria | Measurement |
|----------|----------|-------------|
| 성능 (검색) | keyword 입력 후 결과 ≤ 100ms (10K 거래) | TransactionsDao 검색 쿼리에 인덱스 + 디바운스 |
| 성능 (분석 탭) | 화면 진입 ≤ 300ms (10K 거래 기준) | Drift 집계 쿼리 + Riverpod cache |
| APK 크기 | ≤ 30MB (fl_chart 추가 후) | `flutter build apk --analyze-size` |
| 카드 결제 예측 | due_day 기반 D-day 계산 정확 | 단위 테스트 |

---

## 6. Success Criteria (Definition of Done)

### 6.1 M2 DoD

- [ ] FR-19~FR-32 구현 (전체 또는 명시적 deferred 표시)
- [ ] flutter analyze 0 issues
- [ ] flutter test 모두 통과 (M1 63 + M2 신규 ~15 = ~78)
- [ ] **TransactionRepository 통합 테스트 5건 모두 통과** (M1 deferred 청산)
- [ ] Drift 스키마 v2→v3 마이그레이션 작성 + 디바이스에서 실제 마이그레이션 검증
- [ ] APK 빌드 + 본인 핸드폰 설치 + 6탭 동작 + 카드 상세 + 분석 차트 + 검색 모두 동작 검증
- [ ] M1 데이터 보존 — v3 마이그레이션 후 기존 거래/계좌 정상 표시

### 6.2 Quality Criteria

- [ ] flutter analyze 0 warnings
- [ ] **Repository/Sync 통합 테스트 커버리지 ≥ 60%** (M1 Plan §6.2 청산)
- [ ] 마이그레이션 전후 잔액 무결성 검증 통과 (BalanceReconciler M1 자산 활용)

---

## 7. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Drift 마이그레이션 v2→v3 데이터 손실 | High | Low | 마이그레이션 작성 시 `MigrationStrategy.onUpgrade` + `addColumn` 만 사용. 디바이스 검증 전 in-memory 테스트로 마이그레이션 실행 |
| due_day NULL 허용 → credit_card 외에는 무의미 | Low | High | UI에서 type==credit_card일 때만 입력 필드 노출 + 다른 type은 NULL 강제 |
| 카드 결제일이 매월 달라지는 사용자 (예: 25일/30일 변동) | Medium | Low | M2는 단일 due_day 가정. 변동 결제일은 M3 보완 |
| 6탭 NavigationBar로 라벨 잘림 | Medium | Medium | 짧은 라벨 (홈/입력/내역/계좌/분석/설정) + 아이콘 우선 |
| 검색 성능 (10K 거래 기준) | Medium | Low | `transactions(occurred_at DESC, deleted_at)` 인덱스 활용 + LIKE는 memo만 |
| fl_chart 학습 곡선 | Low | Low | 도너츠 + 라인 둘만 사용. fl_chart 공식 예제 그대로 시작 |
| transfer-to-credit_card 안내가 false-positive | Low | Medium | 명확한 워딩 ("카드값 결제 맞나요?") + 무시 가능한 InfoBox 형태 |
| Repository 통합 테스트 sqlite native binary 셋업 | Medium | Medium | `sqlite3` package dev_dep 추가 + Windows에서 Action 검증. 여전히 막히면 dev/test 환경 분리 |

---

## 8. Architecture Considerations

### 8.1 변경 없는 부분

| 영역 | M1 결정 유지 |
|------|------------|
| 회계 모델 | 4-type Tx + Accounts (변경 없음) |
| 잔액 갱신 | atomic via AccountsDao (변경 없음) |
| 동기화 | 3-시트 SyncService (accounts 시트 컬럼만 due_day 추가) |
| 상태관리 | Riverpod 2.x |
| 라우팅 | GoRouter — 6번째 branch 추가 |
| 로컬 DB | Drift |

### 8.2 신규 모듈

```
lib/
├── features/
│   ├── accounts/ui/
│   │   └── card_detail_screen.dart            # 신규 (FR-19, FR-20)
│   ├── analytics/                             # 신규 모듈
│   │   ├── domain/
│   │   │   └── analytics_metrics.dart         # 카테고리 합계, 고정/변동 분리
│   │   ├── data/
│   │   │   └── analytics_repository.dart      # 집계 쿼리
│   │   └── ui/
│   │       ├── analytics_screen.dart          # 메인 분석 화면
│   │       ├── category_donut.dart            # fl_chart 도너츠
│   │       └── fixed_variable_chart.dart      # 라인 차트
│   ├── transactions/ui/
│   │   ├── search_bar_widget.dart             # 신규 SearchBar
│   │   └── filter_chips.dart                  # 칩 필터
│   └── accounts/ui/
│       └── accounts_screen.dart               # 트리 UI 수정
└── core/db/
    ├── tables.dart                            # accounts.due_day 추가
    └── migrations/                            # 신규
        └── v2_to_v3.dart                      # 마이그레이션 스크립트
```

### 8.3 핵심 데이터 흐름 (분석 탭)

```
User taps 분석 탭
  → AnalyticsScreen
  → ref.watch(currentMonthCategoryDonutProvider)
       AnalyticsRepository.computeCategoryDonut(month)
         SELECT category_id, SUM(amount) FROM transactions
         WHERE type='expense' AND occurred_at IN [month range]
           AND deleted_at IS NULL
         GROUP BY category_id
       → List<CategorySegment>
  → fl_chart PieChart 렌더 (≤ 300ms)
```

### 8.4 핵심 데이터 흐름 (카드 상세)

```
User taps credit_card row in AccountsScreen
  → CardDetailScreen(account)
  → ref.watch(cardDetailProvider(account.id))
       parallel:
         - 이번 달 사용액: SUM(tx.amount) WHERE from_account_id = id AND month = current
         - 다음 결제일: nextDueDate(account.due_day, today) → days until
         - 예상 결제액: account.balance.abs()
         - 최근 10건: SELECT * FROM transactions WHERE from_account_id = id ORDER BY occurred_at DESC LIMIT 10
  → 화면 렌더
```

### 8.5 Drift 마이그레이션 v2→v3

```dart
// app_database.dart
@override
int get schemaVersion => 3;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 3) {
      await m.addColumn(accounts, accounts.dueDay);
    }
  },
  beforeOpen: ...
);
```

---

## 9. Convention Prerequisites

M1과 동일 (Flutter lints + Riverpod naming + Drift naming + 한국어 UI). 추가:

- 마이그레이션 스크립트는 `core/db/migrations/v{from}_to_{to}.dart` 명명
- 차트는 `features/analytics/ui/{chart_name}.dart` 단일 파일 per chart

---

## 10. Milestones

| MS | 범위 | 핵심 작업 | 예상 |
|----|------|-----------|------|
| **M2.1 스키마+카드** | due_day 추가 + 마이그레이션 + AccountForm 업데이트 + 카드 상세 화면 | 마이그레이션 작성 + 테스트, CardDetailScreen, AccountFormSheet 수정 | 3일 |
| **M2.2 분석 탭** | analytics 모듈 + 도너츠 + 라인 차트 + 6탭 추가 | fl_chart 도입, AnalyticsRepository 집계, 차트 위젯 | 3일 |
| **M2.3 검색/필터** | List SearchBar + 칩 필터 + DAO 검색 메서드 | TransactionsDao 검색 쿼리, debounce | 2일 |
| **M2.4 트리+테스트** | 계좌 트리 UI + Repository 통합 테스트 5건 + minor (FR-30) | sqlite3 dev_dep, in-memory 테스트 | 2일 |

총 ~10일 (M1 Plan §10 추정 1.5주와 일치).

---

## 11. Next Steps

1. [ ] Plan 검토 후 → `/pdca design budget-tracker-m2` (Design 문서 + 3 옵션 + Module Map)
2. [ ] M1 Module-8 (release APK) — 별도 사이클로 언제든 가능 (M2와 평행 가능)
3. [ ] M2.1부터 순서대로 구현 (`/pdca do budget-tracker-m2 --scope schema-card`)
4. [ ] M2 사이클 종료 → /pdca analyze → /pdca report

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-04-28 | Initial M2 plan — 카드 상세 + 분석 탭 + 검색·필터 + 트리 UI + Repository 통합 테스트. fl_chart 도입, 스키마 v2→v3 마이그레이션. | kyk@hunik.kr |
