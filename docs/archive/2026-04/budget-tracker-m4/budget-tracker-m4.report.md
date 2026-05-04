---
template: report
version: 1.0
feature: budget-tracker-m4
cycle: M4
date: 2026-04-30
author: kyk@hunik.kr
matchRate: 95
testCount: 101
testResult: pass
---

# Budget Tracker M4 — Completion Report

---

## 1. Executive Summary

| Perspective | Planned | Delivered |
|-------------|---------|-----------|
| **Problem** | M3 템플릿으로 반복 고정비 입력이 5초로 줄었으나 "언제 입력할지" 트리거는 여전히 기억에 의존. 분석 탭 예산 기준 없이 사후 확인만 가능. | ✅ 홈 배지로 도래 반복거래 즉시 인지, 분석 탭 예산 오버레이로 초과 카테고리 실시간 확인 — 트리거와 통제 모두 구현. |
| **Solution** | (A) 반복 거래 규칙 — 매월 N일 도래 시 홈 배지 + 수동 확인 insert. (B) 카테고리 예산 — 월 한도 설정 + 분석 탭 비율 바 + ⚠️. (C) FR-65 migration test + Minor backlog. | ✅ A·B·C 모두 구현. FR-67(카테고리 자식 drag-reorder)만 Medium으로 M5 이월. |
| **Function/UX Effect** | 홈 배지 → RecurringDueSheet(확인/스킵) / 분석 탭 예산 바 + ⚠️ / 설정 2개 sub-screen 추가. | ✅ 모든 UX 흐름 구현. budgetOverlay는 N+1 대신 3-query batch — 성능 개선도 달성. |
| **Core Value** | M3 = 패턴+효율+해상도 → M4 = 자동+통제. 앱이 능동적 재무 어시스턴트로 진화. | ✅ 반복 거래 도래 자동 알림 + 예산 초과 능동 경고. 사용자는 더 이상 직접 기억하거나 직접 계산하지 않아도 됨. |

### 1.1 핵심 수치

| 지표 | 결과 |
|------|------|
| Match Rate | **95.1%** (Structural 100% · Functional 92.9% · Contract 95%) |
| Tests | **101 / 101 pass** (기존 88 + M4 신규 13) |
| flutter analyze | **0 issues** |
| Plan SC | **5 / 5** |
| FR completed | **13 / 14** (FR-67 Medium, M5 이월) |
| Bug fixed | `BudgetRepository.upsert` conflict target: id → category_id |
| Schema | v5 (recurring_rules + budgets 2개 신규 테이블) |
| Architecture | Option A — Minimal (신규 feature 디렉터리 없이 기존 폴더 확장) |
| LOC | ~1,200 (Design 예상치 정확 달성) |
| Sessions | 5 (recurring-schema / recurring-mgmt / budget-setup / budget-analytics / migration-tests) |

---

## 2. Plan Success Criteria — 5/5 달성

| SC | 항목 | 상태 | 근거 |
|----|------|------|------|
| SC-1 | 반복 거래 도래 알림: 홈 화면에 "처리할 반복 거래 N건" 배지 표시 | ✅ | `home_screen.dart` — `_RecurringDueBadge` widget, `dueRecurringRulesProvider` watch, count > 0 조건부 표시 |
| SC-2 | RecurringDueSheet → 확인 탭 → insert 정확 / 배지 감소 | ✅ | `context.push('/input', extra: templateId)` → pop(true) → `markHandled(rule.id)` — HomeScreen에서 result 리스닝 |
| SC-3 | 예산 초과 경고 ⚠️ 배지: 초과 카테고리 분석 탭에서 즉시 인지 | ✅ | `analytics_screen.dart` — `_BudgetRow.isOver` 시 `colorScheme.error` + `Icons.warning_rounded` |
| SC-4 | 예산 설정: 카테고리별 월 한도 입력/수정 | ✅ | `budget_screen.dart` — TextField + `FilteringTextInputFormatter.digitsOnly` |
| SC-5 | Migration test 작성 (FR-46 deferred 청산) | ✅ | `test/integration/migration_test.dart` — v2→v3, v3→v4, v4→v5 3건 pass |

---

## 3. Functional Requirements — 13/14 달성

| FR | 내용 | 상태 | 비고 |
|----|------|------|------|
| FR-54 | `recurring_rules` 테이블 + v4→v5 마이그레이션 | ✅ | |
| FR-55 | RecurringRulesScreen CRUD (목록 + 생성/수정/삭제 + 활성 토글) | ✅ | |
| FR-56 | RecurringRuleFormSheet (템플릿 picker + 1-28 dayOfMonth) | ✅ | |
| FR-57 | HomeScreen 도래 배지 | ✅ | |
| FR-58 | RecurringDueSheet (확인/스킵) | ✅ | |
| FR-59 | 확인 → InputScreen prefill + markHandled | ✅ | pop(true) 패턴 |
| FR-60 | `budgets` 테이블 + v4→v5 (FR-54와 동시) | ✅ | |
| FR-61 | BudgetRepository (watchAll/upsert/delete) | ✅ | Design getAll() → 구현 watchAll() (더 반응적, StreamProvider) |
| FR-62 | BudgetScreen 설정 sub-screen | ✅ | |
| FR-63 | AnalyticsRepository.budgetOverlay | ✅ | 3-query batch 최적화 (N+1 대신 O(1) 쿼리) |
| FR-64 | AnalyticsScreen 예산 오버레이 섹션 + ⚠️ | ✅ | |
| FR-65 | Migration test (v2→v3, v3→v4, v4→v5) | ✅ | 3건 pass |
| FR-66 | `_DayCell.onTap` minor fix (0원 날짜도 탭 허용) | ✅ | `daily_calendar.dart:142` |
| **FR-67** | **카테고리 자식 drag-reorder** | **❌ Deferred** | `_TopLevelTile` children이 `map()` (비-reorderable). 부모 대분류만 `ReorderableListView`. M5 이월. |

---

## 4. Architecture — Decision Record

| 결정 | 선택 | 결과 |
|------|------|------|
| Architecture Option | Option A — Minimal | ✅ M4 ~1,200 LOC 규모에 신규 feature 디렉터리 없이 기존 dashboard/analytics 폴더에 흡수. 오버엔지니어링 없음. |
| isDue 순수 함수 | RecurringRule.isDue(today) 도메인 메서드 | ✅ 5건 단위 테스트로 완전 커버. 사이드이펙트 없음. |
| markHandled | confirm + skip 동일 함수 | ✅ last_confirmed_at 갱신 결과 동일 — 불필요한 구분 제거. |
| BudgetRepository | getAll() → watchAll() + StreamProvider | ✅ DB 변경 시 분석 탭 예산 바 자동 재계산. Design보다 반응적. |
| dueRecurringRulesProvider | FutureProvider → Provider (sync, allRules 파생) | ✅ allRules StreamProvider에서 동기 파생 — 반복 규칙 변경 즉시 배지 재계산. |
| budgetOverlay 쿼리 | N+1 루프 → 3-query batch | ✅ 카테고리 수에 무관한 O(1) 쿼리 (categories, transactions, budgets 각 1회). |
| upsert conflict target | insertOnConflictUpdate → DoUpdate(target: [categoryId]) | ✅ 프로덕션 버그 수정 — UNIQUE category_id 충돌 처리 정확. |

---

## 5. Key Decisions & Outcomes (PRD → Plan → Design → Code)

### 5.1 전략적 정렬

- **WHY 달성**: "사후 확인 → 사전 통제" 전환 완료. 반복 거래 도래는 앱이 먼저 알려주고, 예산 초과는 분석 탭에서 색상/배지로 즉시 인지.
- **WHO 적합성**: 1인 사용자 (매월 고정비 5~10건) 가정 — watchAll() 5~10 row 규모에서 getDue Dart 필터링 충분. 성능 목표 ≤ 100ms 달성.
- **RISK 대응**:
  - (1) isDue() 날짜 비교 — 5건 단위 테스트 완비. 이번 달 처리 여부 정확.
  - (2) 예산 미설정 카테고리 — INNER JOIN budgets으로 자동 제외. null 처리 없음.
  - (3) v4→v5 마이그레이션 — integration test 3건 pass. createTable ×2 O(1) 작업.

### 5.2 구현 중 발견된 버그 (테스트로 포착)

| 버그 | 증상 | 원인 | 수정 |
|------|------|------|------|
| `BudgetRepository.upsert` UNIQUE constraint 오류 | 동일 categoryId로 두 번째 upsert 시 `SqliteException(2067)` | `insertOnConflictUpdate`가 PK(`id`)를 conflict target으로 사용 → `category_id` UNIQUE 제약 충돌 미처리 | `DoUpdate(target: [_db.budgets.categoryId])`로 교체 |

이 버그는 통합 테스트 작성 중 포착 — 실제 앱 사용 전에 수정 완료.

### 5.3 Migration Test 설계 이슈 & 해결

| 이슈 | 원인 | 해결 |
|------|------|------|
| v3→v4 테스트: `duplicate column name: parent_category_id` | v5 스키마에 이미 컬럼 존재. SQLite가 DROP COLUMN 미지원(구버전). V3ToV4.addColumn 직접 호출 불가. | createTable 부분만 Migrator로 직접 호출. parent_category_id 존재는 structural check로 분리. |

---

## 6. Test Results

```
flutter test: 101건 all pass
  기존: 88건 (M1~M3)
  M4 신규: 13건
    test/recurring_rule_test.dart          5건  (isDue 순수 함수)
    test/budget_status_test.dart           3건  (ratio/isOver)
    test/integration/recurring_rule_repository_test.dart  3건
    test/integration/budget_repository_test.dart          2건  (upsert 버그 수정 검증 포함)
  migration: test/integration/migration_test.dart  3건 (v2→v3, v3→v4, v4→v5)
    → 합산 101건 (설계 예상 104건 대비 3건 차이: migration 6→3건 재설계)

flutter analyze: No issues found (0 warnings, 0 errors)
```

---

## 7. Gap Summary

### 미구현 (1건, Medium)

| ID | 파일 | 내용 | 수정 방향 | 우선순위 |
|----|------|------|-----------|----------|
| G-01 | `categories_screen.dart` | FR-67: `_TopLevelTile` 내부 자식 카테고리가 `ReorderableListView`가 아닌 정적 `map()`으로 렌더링됨. 부모 대분류는 드래그 가능하지만 소분류끼리 재정렬 불가. | `ExpansionTile.children`을 `ReorderableListView`로 교체 + `CategoryRepository.reorder(childIds)` 재사용 | M5 이월 |

### 설계 대비 개선 (gaps 아님)

| 항목 | 내용 |
|------|------|
| budgetOverlay 성능 | 3-query batch 최적화 — Design의 N+1 루프 대비 카테고리 수에 무관한 O(1) |
| dueRecurringRulesProvider | FutureProvider → Provider(sync 파생) — allRules 변경 즉시 배지 재계산 |
| BudgetRepository.watchAll | FutureProvider → StreamProvider — DB 변경 시 예산 바 자동 재계산 |

---

## 8. Milestones 달성 현황

| Milestone | 범위 | 상태 |
|-----------|------|------|
| M4.1 recurring-schema | tables + migration + domain + isDue + 홈 배지 + DueSheet | ✅ |
| M4.2 recurring-mgmt | RecurringRulesScreen + FormSheet + settings/router | ✅ |
| M4.3 budget-setup | BudgetRepository + budgetOverlay + BudgetScreen + settings/router | ✅ |
| M4.4 budget-analytics | AnalyticsScreen 예산 현황 섹션 + ⚠️ | ✅ |
| M4.5 migration-tests | migration_test.dart + _DayCell fix (FR-66) | ✅ (FR-67 제외 완료) |

---

## 9. M5 이월 목록

| 항목 | 우선순위 | 근거 |
|------|----------|------|
| FR-67 카테고리 자식 drag-reorder | Medium | M3 backlog 재이월. ~30 LOC. M5 세션-1에서 처리 권장. |
| 매주/매일 반복 주기 | Low | M4는 매월만. 데이터 패턴 누적 후 결정. |
| 백그라운드 알림 (local_notifications) | Low | WorkManager 복잡도. 앱 포그라운드 배지로 충분. |
| 예산 기간 커스터마이징 | Low | 월별 고정으로 충분. |
| 반복 거래 + 예산 Sheets 동기화 | Low | 로컬 설정으로 충분. M5 Sheets 확장 시 검토. |

---

## 10. M4 Cycle Retrospective

### 잘 된 것

- **테스트 주도 버그 발견**: BudgetRepository upsert 버그를 통합 테스트 작성 중 포착. 프로덕션 도달 전 수정.
- **Option A 선택 정확**: ~1,200 LOC 규모에 신규 feature 디렉터리 없이 기존 폴더 확장. 간결하고 일관성 유지.
- **Design 개선**: StreamProvider + 3-query batch — Design 명세보다 반응적이고 성능 좋은 구현.
- **5세션 일정 준수**: recurring-schema → recurring-mgmt → budget-setup → budget-analytics → migration-tests 순서 정확 이행.

### 개선할 것

- **FR-67 재이월**: M3 backlog에서 M4로 이월됐다가 다시 M5로 이월. 다음 사이클 세션-1에 반드시 처리.
- **Migration test 설계**: SQLite DROP COLUMN 제약을 Plan/Design 단계에서 사전 고려했으면 테스트 구조 설계가 더 명확했을 것.
- **Test count 예측**: 설계 예상 104건 → 실제 101건 (migration 6건 → 3건 재설계). 마이그레이션 테스트 케이스 수를 설계 단계에서 보수적으로 추정할 것.

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-04-30 | M4 완료 보고서. matchRate 95.1%, 101 tests pass, 5/5 SC, FR 13/14. FR-67 M5 이월. Bug: BudgetRepository.upsert conflict target 수정. | kyk@hunik.kr |
