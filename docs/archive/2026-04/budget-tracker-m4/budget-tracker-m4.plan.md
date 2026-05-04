---
template: plan
version: 1.0
feature: budget-tracker-m4
cycle: M4
date: 2026-04-30
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.5.0"
level: Dynamic
basePlan: docs/01-plan/features/budget-tracker-m3.plan.md
baseReport: docs/04-report/budget-tracker-m3.report.md
---

# Personal Budget Tracker — M4 Cycle Planning

> **Summary**: M3 템플릿으로 반복 고정비 입력이 빨라졌다. M4는 "도래 알림"과 "예산 한도"로 마무리 — 앱이 먼저 알려주고, 내가 초과했는지 즉시 인지.
>
> **Cycle**: M4 (M3 완료 후속)
> **Status**: Draft
> **Method**: Plan (도메인 모델은 M1~M3에서 확정, 2개 신규 테이블 추가)

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | M3 템플릿으로 반복 고정비 입력이 5초로 줄었으나 "언제 입력할지" 트리거는 여전히 기억에 의존. 분석 탭에서 카테고리 지출을 볼 수 있지만 "예산 초과" 경고 없이 사후 확인만 가능. 가계부가 수동 체크에서 능동 안내로 넘어가지 못함. |
| **Solution** | (A) **반복 거래 규칙** — 매월 N일 도래 시 홈 화면 배지 + 수동 확인 insert (M3 템플릿 prefill 재사용). (B) **카테고리 예산** — 카테고리별 월 한도 설정, 분석 탭 도너츠 아래 예산 비율 바 + 초과 ⚠️. (C) M3 backlog 청산 — FR-46 migration test + _DayCell minor fix + 카테고리 자식 drag-reorder. |
| **Function/UX Effect** | 홈 화면에 "처리할 반복 거래 N건" 배지 → 탭 → RecurringDueSheet(확인/스킵). 분석 탭 도너츠 아래 카테고리별 예산 바(지출/한도 %) + ⚠️ 초과 하이라이트. 설정에 "반복 거래 관리" + "예산 관리" 2개 sub-screen 추가. |
| **Core Value** | M3 = 패턴+효율+해상도 → **M4 = 자동+통제**. 앱이 매월 결제일을 먼저 알려주고, 카테고리 예산 초과를 실시간 경고. 가계부가 진짜 "능동적 재무 어시스턴트"로 한 단계 진화. |

---

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 반복 고정비 입력 트리거 자동화 + 예산 초과 능동 경고 → 사후 확인이 아닌 사전 통제 |
| **WHO** | 본인 1인 (M1~M3 사용자). 매월 고정비 5~10건 + 카테고리별 예산 의식 있음 |
| **RISK** | (1) recurring rule "이번 달 처리 여부" 상태 관리 — last_confirmed_at 날짜 비교 로직. (2) 예산 데이터 없는 카테고리 처리 — 예산 미설정 시 오버레이 미표시. (3) v4→v5 마이그레이션 신규 테이블 2개 동시 생성. |
| **SUCCESS** | 반복 거래 도래 시 홈 배지 표시 / 확인 탭 → insert 정확 / 예산 초과 카테고리 분석 탭에서 즉시 인지 / migration test 작성 |
| **SCOPE** | 반복 거래(매월) + 예산(카테고리별) + FR-46 migration test + Minor backlog. 양방향 Sheets sync·월별 리포트·매주/매일 반복은 M5+ |

---

## 1. User Intent Discovery

### 1.1 Core Problem (M3 사용 후 발견)

M3까지 구현한 것:
- 자주 쓰는 거래 → 템플릿 저장 → InputScreen "📋 템플릿에서" 5초 입력
- 분석 탭 → 카테고리 도너츠 → 이번 달 어디서 얼마 썼는지

**그러나 여전히 남은 불편:**
- "이번 달 월세 입력했나?" → 캘린더 없이 기억해야 함. 템플릿 있지만 트리거가 없음.
- "식비 예산 초과인지?" → 도너츠에서 퍼센트 확인해야 하지만 기준값(예산)이 없어 직관적 판단 불가.
- M3 FR-46 (migration dedicated test) deferred로 미완성.
- M3 Design §5.9 카테고리 자식 drag-reorder 미구현.

### 1.2 Target Users

| User Type | Usage Context | Key Need |
|-----------|---------------|----------|
| 본인 (M3 사용자, 1-2개월 데이터 누적) | 매월 고정비 입력 알림 + 카테고리 예산 한도 확인 | 앱이 먼저 알려주고, 초과 여부를 색상/배지로 인지 |

### 1.3 Success Criteria

- [ ] **반복 거래 도래 알림**: 매월 설정일에 홈 화면에 "처리할 반복 거래 N건" 배지 표시
- [ ] **반복 거래 insert**: RecurringDueSheet에서 확인 탭 → InputScreen prefill + 저장 → 배지 감소
- [ ] **예산 초과 경고**: 카테고리 지출이 예산 한도 초과 시 분석 탭에서 ⚠️ 배지 표시
- [ ] **예산 설정**: 설정 화면에서 카테고리별 월 한도 입력/수정 가능
- [ ] **Migration test**: FR-46 deferred — v2→v3, v3→v4, v4→v5 in-memory migration test 작성

### 1.4 Constraints

| Constraint | Details | Impact |
|------------|---------|--------|
| 반복 매월만 | 매주/매일은 M5+. M4는 `day_of_month` 단일 필드로 단순화 | Medium |
| 수동 확인 방식 | 백그라운드 스케줄러 없음. 앱 시작/포그라운드 복귀 시 체크 | Medium |
| 예산 미설정 카테고리 | 예산 없는 카테고리는 도너츠에서 오버레이 생략 (단순 표시) | Low |
| Schema v5 | recurring_rules + budgets 2개 신규 테이블 (v4→v5 마이그레이션) | High |
| Sheets sync 제외 | 반복 거래 규칙 + 예산은 로컬 설정. Sheets는 M5 검토 | Low |

---

## 2. Alternatives Briefly Considered

### 2.1 반복 거래 실행 시점

| 옵션 | 장단점 | 결정 |
|------|--------|------|
| **홈 배지 + 수동 확인 (선택)** | 구현 단순. 실수 없음. 사용자 의도 확인 | ✅ |
| 자동 insert (앱 시작) | 빠르지만 금액 수정 기회 없음. 실수 입력 위험 | ❌ |
| Flutter local_notifications | 앱 미실행 중 푸시. 복잡도 높음, M5 검토 | M5 |

### 2.2 예산 단위

| 옵션 | 장단점 | 결정 |
|------|--------|------|
| **카테고리별 월 한도 (선택)** | M3 도너츠와 자연스럽게 연계. 직관적 | ✅ |
| 월 전체 합산 한도 | 단순하지만 카테고리 분석과 연계 단절 | ❌ |
| 기간별 예산 | 가장 유연하지만 M4 scope 초과 | M5 |

### 2.3 예산 UI 위치

| 옵션 | 장단점 | 결정 |
|------|--------|------|
| **분석 탭 도너츠 아래 바 테이블 (선택)** | 지출+예산 한눈에 | ✅ |
| 별도 "예산" 탭 | 7탭 과밀. 예산이 분석과 별개로 격리 | ❌ |
| 홈 카드 | 홈 고밀도 증가 | M5 검토 |

---

## 3. YAGNI Review

### 3.1 Included (M4 Must-Have)

- [ ] `recurring_rules` 테이블 + Drift 마이그레이션 v4→v5
- [ ] RecurringRuleRepository: getDue(today), confirm(id), skip(id), CRUD
- [ ] 홈 화면 도래 배지 (앱 포그라운드 진입 시 체크)
- [ ] RecurringDueSheet — 도래 항목 목록 + 확인/스킵
- [ ] 확인 → InputScreen prefill (M3 applyTemplate 재사용)
- [ ] 설정 화면 "반복 거래 관리" sub-screen (목록 + 생성/수정/삭제)
- [ ] RecurringRuleFormSheet — 템플릿 선택 + 날짜 선택
- [ ] `budgets` 테이블 (recurring_rules와 동시에 v4→v5)
- [ ] BudgetRepository: getAll(), upsert(categoryId, limit), delete(categoryId)
- [ ] 설정 화면 "예산 관리" sub-screen (카테고리별 한도 입력)
- [ ] AnalyticsRepository.budgetOverlay(month) — 지출 + 예산 비율
- [ ] AnalyticsScreen 예산 오버레이 바 테이블 + ⚠️ 초과 배지
- [ ] FR-46 migration test: v2→v3, v3→v4, v4→v5 in-memory
- [ ] _DayCell.onTap 삼항 minor fix (M3 §6 Minor)
- [ ] 카테고리 자식 drag-reorder UI (M3 §6 Important #2, ~30 LOC)

### 3.2 Deferred (M5+)

| Feature | Reason | Revisit |
|---------|--------|---------|
| 매주/매일 반복 주기 | M4는 매월만. 데이터 패턴 확인 후 | M5 |
| 백그라운드 알림 (local_notifications) | WorkManager/BGProcessingTask 복잡도 | M5 |
| 예산 기간 커스터마이징 | 월별 고정으로 충분 | M5 |
| 예산/반복 Sheets 동기화 | 로컬 설정으로 충분 | M5 |
| 월별·연도별 리포트 화면 | Sheets export로 커버 | M5 |
| 반복 거래 종료 날짜 / N회 | 단순 무한 반복으로 충분 (비활성화로 중지) | M5 |

### 3.3 Removed (Won't Do)

| Feature | Reason |
|---------|--------|
| 예산 달성 시 긍정 피드백 | 초과 경고가 핵심. 달성 UI는 없어도 됨 |
| 반복 거래 히스토리 화면 | 거래는 이미 ListScreen에서 볼 수 있음 |
| 예산 vs 전월 비교 | M3 라인 차트가 추세 제공, 중복 |

---

## 4. Scope

### 4.1 In Scope (M4)

- `recurring_rules` 테이블 + v4→v5 마이그레이션 (budgets 동시)
- RecurringRule domain + DAO + Repository
- RecurringRulesScreen (설정 sub) + RecurringRuleFormSheet
- HomeScreen 도래 배지 + RecurringDueSheet
- `budgets` 테이블 + Budget domain + DAO + Repository
- BudgetScreen (설정 sub)
- AnalyticsRepository.budgetOverlay + AnalyticsScreen 예산 오버레이
- FR-46 + _DayCell fix + 카테고리 자식 drag-reorder

### 4.2 Out of Scope (M4)

- 매주/매일 반복, 백그라운드 알림, 양방향 sync, 월별 리포트 (M5)
- 예산 기간 커스터마이징, 반복 종료 날짜

---

## 5. Requirements

### 5.1 Functional Requirements (M4 신규)

| ID | Requirement | Priority | Status |
|----|-------------|:--------:|:------:|
| FR-54 | `recurring_rules` 테이블: id / template_id(FK) / day_of_month(1-28) / is_active / last_confirmed_at(NULLABLE) + Drift 마이그레이션 v4→v5 | High | Pending |
| FR-55 | RecurringRule CRUD — 설정 화면 "반복 거래 관리" sub-screen (목록 + 생성/수정/삭제) | High | Pending |
| FR-56 | RecurringRuleFormSheet — TxTemplate picker + day_of_month 입력 (1~28) | High | Pending |
| FR-57 | HomeScreen: 앱 포그라운드 진입 시 getDue(today) 체크 → 도래 N건 배지 표시 | High | Pending |
| FR-58 | RecurringDueSheet: 도래 항목 목록 + "확인" (→ InputScreen template prefill) + "스킵" (이번 달 건너뜀) | High | Pending |
| FR-59 | 확인 tap → InputScreen template prefill, 거래 저장 성공 시 last_confirmed_at = today 갱신 | High | Pending |
| FR-60 | `budgets` 테이블: id / category_id(FK, UNIQUE) / monthly_limit(>0) + v4→v5 마이그레이션 (FR-54와 동시) | High | Pending |
| FR-61 | BudgetRepository: getAll() / upsert(categoryId, limit) / delete(categoryId) | High | Pending |
| FR-62 | 설정 화면 "예산 관리" sub-screen: 카테고리 목록 + 현재 한도 표시 + 탭하면 한도 수정 | High | Pending |
| FR-63 | AnalyticsRepository.budgetOverlay(month) → List<BudgetStatus>: categoryId / categoryName / spent / limit / ratio / isOver | High | Pending |
| FR-64 | AnalyticsScreen 도너츠 아래 예산 오버레이 섹션: 예산 있는 카테고리만 표시, 지출/한도 바 + ⚠️ 초과 배지 | High | Pending |
| FR-65 | FR-46 deferred 청산 — v2→v3, v3→v4, v4→v5 in-memory migration dedicated test | Medium | Pending |
| FR-66 | `_DayCell.onTap` 삼항 minor fix (M3 §6 Minor) | Low | Pending |
| FR-67 | 카테고리 관리 화면에 자식 카테고리 ReorderableListView 적용 (M3 §6 Important #2) | Medium | Pending |

### 5.2 Non-Functional Requirements

| Category | Criteria | Measurement |
|----------|----------|-------------|
| 반복 거래 체크 | 홈 포그라운드 진입 후 배지 갱신 ≤ 100ms | DAO getDue 단순 쿼리 |
| 예산 오버레이 | 분석 탭 기존 데이터 + 예산 조회 ≤ 300ms | budgetOverlay join 쿼리 |
| 마이그레이션 | v4→v5 ≤ 500ms (테이블 2개 신규, 데이터 이동 없음) | createTable O(1) |

---

## 6. Success Criteria (Definition of Done)

### 6.1 M4 DoD

- [ ] FR-54~67 구현 (전체 또는 명시적 deferred 표시)
- [ ] flutter analyze 0 issues
- [ ] flutter test 모두 통과 (기존 ~92 + M4 신규 ~12 = ~104건)
- [ ] **FR-65 migration test 5건 (v2→v3 2, v3→v4 2, v4→v5 2)** 모두 통과
- [ ] M3 디바이스(v4 db) → v5 마이그레이션 무손실 검증
- [ ] 반복 거래 1건 생성 → 설정일 도래 → 홈 배지 → 확인 → 거래 저장 흐름 수동 검증

### 6.2 Quality Criteria

- [ ] flutter analyze 0 warnings
- [ ] Repository/Migration 통합 테스트 커버리지 ≥ 60% 유지
- [ ] RecurringRule `last_confirmed_at` 로직 단위 테스트 (isDue pure function)

---

## 7. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `last_confirmed_at` 비교 로직 — 같은 달 중복 insert | High | Medium | `isDue(today)` 순수 함수로 추출 + 단위 테스트 필수. 조건: dayOfMonth ≤ today.day && (lastConfirmedAt == null ∥ lastConfirmedAt!.year < today.year ∥ lastConfirmedAt!.month < today.month) |
| 예산 미설정 카테고리 오버레이 처리 | Low | High | budgetOverlay는 `JOIN budgets` 대신 `LEFT JOIN` — 예산 없는 카테고리는 List에서 제외 (null-safe filter) |
| v4→v5 2개 테이블 동시 생성 | Medium | Low | M3 패턴(createTable + addColumn 동시) 확장. in-memory test(FR-65)로 사전 검증 |
| RecurringDueSheet → InputScreen → 저장 후 돌아오기 | Medium | Medium | GoRouter push/pop 흐름. InputScreen 저장 성공 callback으로 `confirmRule` 호출. 취소 시 rule 상태 변경 없음 |
| 카테고리 drag-reorder와 기존 정렬 충돌 | Low | Low | sortOrder UPDATE는 기존 `reorder()` 로직 확장. 부모↔자식 섞임 방지: 자식은 자식끼리만 reorder |

---

## 8. Architecture Considerations

### 8.1 변경 없는 부분

| 영역 | M3 결정 유지 |
|------|------------|
| 회계 모델 | 4-type Tx (변경 없음) |
| Sheets 동기화 | one-way push (pull M5) |
| 상태관리 | Riverpod 2.x |
| 라우팅 | GoRouter (4탭 + FAB, 추가 routes만) |

### 8.2 신규 모듈

```
lib/
├── features/
│   ├── recurring/                              # 🆕 신규 모듈
│   │   ├── domain/recurring_rule.dart          # RecurringRule + isDue() pure func
│   │   ├── data/
│   │   │   ├── recurring_rules_dao.dart        # Drift DAO
│   │   │   └── recurring_rule_repository.dart  # getDue / confirm / skip / CRUD
│   │   └── ui/
│   │       ├── recurring_rules_screen.dart     # 설정 sub-screen 목록
│   │       ├── recurring_rule_form_sheet.dart  # 생성/수정 폼
│   │       └── recurring_due_sheet.dart        # 도래 항목 처리 시트
│   └── budget/                                 # 🆕 신규 모듈
│       ├── domain/budget.dart                  # Budget + BudgetStatus
│       ├── data/
│       │   ├── budgets_dao.dart                # Drift DAO
│       │   └── budget_repository.dart          # getAll / upsert / delete
│       └── ui/
│           └── budget_screen.dart              # 설정 sub-screen
```

### 8.3 핵심 데이터 흐름 (반복 거래)

```
앱 포그라운드 진입 (HomeScreen lifecycle)
  → ref.read(dueRecurringRulesProvider)
       RecurringRuleRepository.getDue(today)
         SELECT * FROM recurring_rules
         WHERE is_active = 1
           AND day_of_month <= today.day
           AND (last_confirmed_at IS NULL
                OR strftime('%Y-%m', last_confirmed_at) < today.yearMonth)
       → List<RecurringRule>
  → count > 0 → 홈 배지 표시
  → 사용자 탭 → RecurringDueSheet
  → 각 항목 "확인" → InputScreen(templateId: rule.templateId)
  → 저장 성공 → repository.confirm(rule.id, today)
               → UPDATE recurring_rules SET last_confirmed_at = now
```

### 8.4 핵심 데이터 흐름 (예산 오버레이)

```
AnalyticsScreen 월 선택 변경
  → ref.watch(budgetOverlayProvider(month))
       AnalyticsRepository.budgetOverlay(month)
         SELECT c.id, c.name, SUM(t.amount), b.monthly_limit
         FROM categories c
         LEFT JOIN transactions t ON ... (month filter)
         INNER JOIN budgets b ON b.category_id = c.id
         WHERE t.type = 'expense' AND t.deleted_at IS NULL
         GROUP BY c.id
       → List<BudgetStatus>
  → 예산 있는 카테고리만 오버레이 섹션 표시
  → ratio > 1.0 → ⚠️ 배지
```

### 8.5 Schema v5 Delta

```dart
// recurring_rules 신규
class RecurringRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get templateId => integer()
      .customConstraint('NOT NULL REFERENCES tx_templates(id)')();
  IntColumn get dayOfMonth => integer()(); // 1-28
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastConfirmedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

// budgets 신규
class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer()
      .unique()
      .customConstraint('NOT NULL REFERENCES categories(id)')();
  IntColumn get monthlyLimit => integer()(); // > 0 enforced at app level
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
```

---

## 9. Convention Prerequisites

M1~M3와 동일 (Flutter lints + Riverpod naming + Drift naming + 한국어 UI). 추가:

- 반복 거래 도래 여부: `RecurringRule.isDue(today)` — **순수 함수**, 사이드이펙트 없음. 단위 테스트 필수.
- 예산 비율: `BudgetStatus.ratio` — double (> 1.0 = 초과). UI에서 clamp(0, 1.0) for bar, isOver로 배지.
- migration test 파일: `test/integration/migration_test.dart` — 단일 파일에 v2→v3, v3→v4, v4→v5 모두.

---

## 10. Milestones

| MS | 범위 | 핵심 작업 | 예상 |
|----|------|-----------|------|
| **M4.1 recurring-schema** | recurring_rules 테이블 + v4→v5 마이그레이션 + DAO + Repository + 홈 배지 + RecurringDueSheet | 마이그레이션, isDue 순수 함수 단위 테스트, DueSheet + confirm/skip 흐름 | 2일 |
| **M4.2 recurring-mgmt** | RecurringRulesScreen (설정) + RecurringRuleFormSheet + router | 설정 sub-screen CRUD, templateId 선택 picker | 2일 |
| **M4.3 budget-setup** | budgets 테이블(v4→v5 동시) + BudgetDAO + Repository + BudgetScreen (설정) | 설정 sub-screen 카테고리 목록 + 한도 입력 | 2일 |
| **M4.4 budget-analytics** | AnalyticsRepository.budgetOverlay + AnalyticsScreen 예산 오버레이 + ⚠️ 배지 | LEFT JOIN 쿼리, 분석 탭 UI 통합 | 2일 |
| **M4.5 migration-tests** | FR-65 migration test + FR-66 _DayCell fix + FR-67 drag-reorder | Drift in-memory migration runner, minor UI fixes | 1일 |

총 ~9일 (M3 ~12일보다 가벼움 — 신규 모듈 2개, 기존 UI 확장).

---

## 11. Next Steps

1. [ ] Plan 검토 후 → `/pdca design budget-tracker-m4`
2. [ ] M4.1부터 순서대로 구현 (`/pdca do budget-tracker-m4 --scope recurring-schema`)
3. [ ] M4 사이클 종료 → `/pdca analyze budget-tracker-m4` → `/pdca report budget-tracker-m4`

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-04-30 | Initial M4 plan — 반복 거래(매월/홈배지/수동확인) + 예산(카테고리별 월한도/분석 오버레이) + FR-65~67 backlog 청산. Schema v5(2 tables). 5 sessions ~9일. | kyk@hunik.kr |
