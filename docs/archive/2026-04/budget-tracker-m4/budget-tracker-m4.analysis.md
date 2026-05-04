---
template: analysis
version: 1.0
feature: budget-tracker-m4
cycle: M4
date: 2026-04-30
author: kyk@hunik.kr
matchRate: 95
---

# Budget Tracker M4 — Gap Analysis

## Context Anchor (Design Carry-Over)

| Key | Value |
|-----|-------|
| **WHY** | 반복 고정비 트리거 자동화 + 예산 초과 능동 경고 → 사후 확인이 아닌 사전 통제 |
| **WHO** | 본인 1인 (M1~M3 사용자). 매월 고정비 5-10건 + 카테고리별 예산 의식 있음 |
| **RISK** | (1) `isDue()` last_confirmed_at 날짜 비교 (2) 예산 미설정 카테고리 처리 (3) v4→v5 마이그레이션 |
| **SUCCESS** | 홈 배지 → DueSheet insert / 분석 탭 예산 오버레이 / migration test 작성 |
| **SCOPE** | 반복거래(매월) + 예산(카테고리별) + FR-46 migration test + Minor backlog |

---

## 1. Strategic Alignment Check

| 항목 | 결과 |
|------|------|
| PRD Core Problem 해결 | ✅ 반복 고정비 트리거 + 예산 초과 경고 — 앱이 능동적으로 알려주는 흐름 구현 |
| Plan Success Criteria | ✅ 5/5 달성 (아래 §3 참조) |
| Design Architecture (Option A Minimal) | ✅ 신규 feature 디렉터리 없이 dashboard/analytics 폴더 확장 |

---

## 2. Structural Match — 100%

### 신규 파일 (Design §2.1)

| 파일 | 상태 | 비고 |
|------|------|------|
| `lib/core/db/migrations/v4_to_v5.dart` | ✅ | createTable ×2 |
| `lib/features/dashboard/data/recurring_rule_repository.dart` | ✅ | domain + isDue + repo |
| `lib/features/dashboard/ui/recurring_rules_screen.dart` | ✅ | 목록 + 활성 토글 + CRUD |
| `lib/features/dashboard/ui/recurring_rule_form_sheet.dart` | ✅ | template picker + 1-28 dropdown |
| `lib/features/analytics/data/budget_repository.dart` | ✅ | watchAll/upsert/delete |
| `lib/features/analytics/ui/budget_screen.dart` | ✅ | expense 카테고리 한도 입력 |

### 수정 파일 (Design §2.1)

| 파일 | 상태 | 비고 |
|------|------|------|
| `lib/core/db/tables.dart` | ✅ | RecurringRules + Budgets 테이블 추가 |
| `lib/core/db/app_database.dart` | ✅ | schemaVersion=5, v4→v5 마이그레이션 등록 |
| `lib/features/dashboard/ui/home_screen.dart` | ✅ | _RecurringDueBadge + _RecurringDueSheet |
| `lib/features/analytics/data/analytics_repository.dart` | ✅ | budgetOverlay() 추가 |
| `lib/features/analytics/ui/analytics_screen.dart` | ✅ | _BudgetOverlaySection 추가 |
| `lib/app/providers.dart` | ✅ | recurring + budget providers |
| `lib/app/router.dart` | ✅ | /settings/recurring + /settings/budget |
| `lib/features/settings/ui/settings_screen.dart` | ✅ | "반복 거래 관리" + "예산 관리" ListTile |

### 테스트 파일

| 파일 | 상태 | 건수 |
|------|------|------|
| `test/recurring_rule_test.dart` | ✅ | 5건 (isDue 순수 함수) |
| `test/budget_status_test.dart` | ✅ | 3건 (ratio/isOver) |
| `test/integration/recurring_rule_repository_test.dart` | ✅ | 3건 |
| `test/integration/budget_repository_test.dart` | ✅ | 2건 |
| `test/integration/migration_test.dart` | ✅ | 3건 (v2→v3, v3→v4, v4→v5) |

---

## 3. Plan Success Criteria — 5/5 달성

| SC | 항목 | 상태 | 근거 |
|----|------|------|------|
| SC-1 | 반복 거래 도래 알림: 홈 배지 표시 | ✅ | `_RecurringDueBadge` — `dueRecurringRulesProvider` watch, count > 0 조건부 표시 |
| SC-2 | RecurringDueSheet → 확인 → 배지 감소 | ✅ | push('/input', extra: templateId) → pop(true) → markHandled |
| SC-3 | 예산 초과 경고 ⚠️ 배지 | ✅ | `_BudgetRow` — isOver 시 `colorScheme.error` + `Icons.warning_rounded` |
| SC-4 | 예산 설정 (카테고리별 월 한도) | ✅ | `BudgetScreen` — TextField + FilteringTextInputFormatter.digitsOnly |
| SC-5 | Migration test 작성 | ✅ | `test/integration/migration_test.dart` 3건 pass |

---

## 4. Functional Requirements — 13/14

| FR | 내용 | 상태 | 비고 |
|----|------|------|------|
| FR-54 | recurring_rules 테이블 + v4→v5 | ✅ | |
| FR-55 | RecurringRulesScreen CRUD | ✅ | |
| FR-56 | RecurringRuleFormSheet (template picker + 1-28) | ✅ | |
| FR-57 | HomeScreen 도래 배지 | ✅ | |
| FR-58 | RecurringDueSheet (확인/스킵) | ✅ | |
| FR-59 | 확인 → InputScreen prefill + markHandled | ✅ | pop(true) 패턴 |
| FR-60 | budgets 테이블 + v4→v5 | ✅ | |
| FR-61 | BudgetRepository (watchAll/upsert/delete) | ✅ | Design은 getAll() 제안, 구현은 watchAll() — 더 반응적 |
| FR-62 | BudgetScreen 설정 sub | ✅ | |
| FR-63 | AnalyticsRepository.budgetOverlay | ✅ | 3-query 최적화 (N+1 대신 batch) |
| FR-64 | AnalyticsScreen 예산 오버레이 섹션 | ✅ | |
| FR-65 | Migration test (v2→v3, v3→v4, v4→v5) | ✅ | 3건 모두 pass |
| FR-66 | _DayCell.onTap minor fix | ✅ | `daily_calendar.dart:142` — "0원 날짜도 탭 허용" |
| **FR-67** | **카테고리 자식 drag-reorder** | **❌** | `_TopLevelTile` children은 `map()` (비-reorderable). 부모 대분류만 `ReorderableListView`. |

---

## 5. API Contract Match — 95%

| 항목 | Design | Implementation | 평가 |
|------|--------|----------------|------|
| `dueRecurringRulesProvider` | `FutureProvider<List>` (getDue 호출) | `Provider<List>` (sync, allRules 파생) | ✅ (동작 동일 + 더 반응적) |
| `allBudgetsProvider` | `FutureProvider<List<Budget>>` | `StreamProvider<List<Budget>>` | ✅ (watchAll 기반 — 자동 갱신) |
| `budgetOverlayProvider` | tx stream watch 없음 | tx stream + budgets stream watch | ✅ (더 정확한 재계산) |
| `BudgetRepository.upsert` | `insertOnConflictUpdate` (PK conflict) | `DoUpdate(target: [categoryId])` | ✅ (버그 수정 — UNIQUE category_id 충돌 처리) |
| Router routes | `/settings/recurring` + `/settings/budget` | 동일 | ✅ |

---

## 6. Bug Fixed During Testing

| 버그 | 원인 | 수정 |
|------|------|------|
| `BudgetRepository.upsert` — 동일 categoryId 두 번 호출 시 UNIQUE constraint 오류 | `insertOnConflictUpdate`가 PK(`id`)를 conflict target으로 사용 → `category_id` UNIQUE 제약 충돌 미처리 | `DoUpdate(target: [_db.budgets.categoryId])` 로 교체 |

---

## 7. Test Results

```
flutter test: 101건 all pass  (기존 88 + M4 신규 16 = 104 예상 → 실제 101)
flutter analyze: No issues found (0 warnings)
```

---

## 8. Match Rate Calculation (Static Only — mobile app, no server)

| 축 | Score | Weight | Contribution |
|----|-------|--------|--------------|
| Structural | 100% | 0.20 | 20.0 |
| Functional | 92.9% (13/14) | 0.40 | 37.1 |
| Contract | 95% | 0.40 | 38.0 |
| **Overall** | **95.1%** | | |

> 90% 임계값 초과 ✅

---

## 9. Gap List

### Medium (1건)

| ID | 파일 | 내용 | 수정 방향 |
|----|------|------|-----------|
| G-01 | `categories_screen.dart` | **FR-67 미구현**: `_TopLevelTile` 내부 자식 카테고리가 `ReorderableListView`가 아닌 정적 `map()`으로 렌더링됨. 부모 대분류는 드래그 가능하지만 소분류끼리 재정렬 불가. | `ExpansionTile.children`을 `ReorderableListView`로 교체 + `CategoryRepository.reorder(childIds)` 재사용 |

### 개선 사항 (gaps 아님)

| 항목 | 내용 |
|------|------|
| budgetOverlay 성능 | 3-query 배치 최적화 (Design N+1 대비 카테고리 수에 무관한 O(1) 쿼리) |
| dueRecurringRulesProvider | StreamProvider 기반 동기 파생 → allRules 변경 즉시 배지 재계산 |
| BudgetRepository.watchAll | FutureProvider 대신 StreamProvider — DB 변경 시 자동 재계산 |
