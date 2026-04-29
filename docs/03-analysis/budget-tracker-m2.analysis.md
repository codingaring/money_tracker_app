---
template: analysis
version: 1.0
feature: budget-tracker-m2
cycle: M2
date: 2026-04-29
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.3.0"
level: Dynamic
basePlan: docs/01-plan/features/budget-tracker-m2.plan.md
baseDesign: docs/02-design/features/budget-tracker-m2.design.md
matchRate: 99
structuralRate: 100
functionalRate: 98
contractRate: 100
---

# Budget Tracker — M2 Static Gap Analysis

> **Static Match Rate: 99%** (≥ 90% threshold). 0 Critical / 3 Important.

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 누적 데이터로 본인 소비 패턴 이해 + 카드 결제 예측 |
| **WHO** | 본인 1인 (M1 사용자, 1-2주 데이터 누적) |
| **RISK** | 6탭 좁아짐 / 카드 결제일 부재 / 차트 학습 곡선 / 검색 성능 |
| **SUCCESS** | 카드 결제 예정 정확 / 카테고리 분석 매월 1회 / 검색 ≤ 100ms / 통합 테스트 60% |
| **SCOPE** | 카드 상세 + 분석 탭 + 검색·필터 + 계좌 트리 + Repo 통합 테스트 |

## Match Rate Breakdown

```
Structural × 0.2 = 100 × 0.2 = 20.0
Functional × 0.4 =  98 × 0.4 = 39.2
Contract   × 0.4 = 100 × 0.4 = 40.0
─────────────────────────────────────
Overall                       = 99.2 → 99%
```

## Plan Success Criteria

| # | Criteria | Status | Evidence |
|---|----------|:------:|----------|
| SC-1 | 카드 결제 예정 D-day + 예상 금액 | ✅ Met | card_detail_repository.dart:101-110 + card_detail_screen.dart:62-185 |
| SC-2 | 카테고리 도너츠 + 고정/변동 라인 | ✅ Met | analytics_repository.dart + analytics_screen.dart + 두 차트 wrapper |
| SC-3 | 검색 응답 ≤ 100ms | ⚠️ Partial | 정적 최적화 OK (memo-LIKE-when-keyword + 250ms debounce + indexed). **수치는 디바이스 측정 필요** |
| SC-4 | 계좌 트리 | ✅ Met | accounts_screen.dart:69-129 + parent dropdown |
| SC-5 | TransactionRepository 통합 테스트 5건 | ✅ Met | test/integration/transaction_repository_test.dart 5건 (M1 deferred 청산) |

## Decision Record Compliance — 7/7

| Decision | Followed? |
|----------|:---------:|
| Architecture Option C (Pragmatic) | ✅ |
| Card detail = AccountsScreen drill-down (not new tab) | ✅ |
| 6 tabs with 분석 in 5번째 | ✅ |
| Migration `core/db/migrations/v{n}_to_{m}.dart` | ✅ |
| Search keyword = memo만 (LIKE) | ✅ |
| fl_chart for charts | ✅ |
| sqlite3 dev_dep for in-memory tests | ✅ |

## Issues — 0 Critical / 3 Important

### Important #1 — D-0 동작 wording 차이 (90%)
`computeNextDueDate`가 같은 날짜면 D-0 반환. Design §4.2 의사코드와 결과는 같지만 wording 모호.
→ **권고**: Design §4.2 "today returns D-0" 명시. 코드 변경 불필요.

### Important #2 — 트리 cross-bucket 머지 미구현 (85%)
AccountsScreen이 bucket headers를 유지하면서 indent. Design §5.5 mock은 cross-bucket merge 의도.
→ **권고**: 본인 1인 맥락에서 현재 동작도 직관적. Design §5.5 mock 업데이트 또는 M3로 이연.

### Important #3 — Parent dropdown은 cash type만 (80%)
Design §5.6과 일치하지만 명시되지 않은 제약.
→ **권고**: Design §5.6에 "only cash accounts can be parents" 명시.

## Recommended Next Step

**Proceed to `/pdca report budget-tracker-m2`** — iterate 불필요.
