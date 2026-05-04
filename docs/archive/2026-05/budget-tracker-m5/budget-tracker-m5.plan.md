---
template: plan
version: 1.0
feature: budget-tracker-m5
cycle: M5
date: 2026-04-30
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.6.0"
level: Dynamic
basePlan: docs/01-plan/features/budget-tracker-m4.plan.md
baseReport: docs/archive/2026-04/budget-tracker-m4/budget-tracker-m4.report.md
---

# Personal Budget Tracker — M5 Cycle Planning

> **Summary**: M4로 "자동+통제" 완성. M5는 세 축 — (1) M4 backlog 청산(FR-67), (2) 반복 거래 주기 확장(매주/매일), (3) 연간 흐름을 한눈에 보는 리포트 탭 신규 추가.
>
> **Cycle**: M5 (M4 완료 후속)
> **Status**: Draft
> **Method**: Plan (schema v6 마이그레이션 + 신규 reports feature)

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | M4까지 월별 예산+반복거래 알림으로 단기 통제 완성. 그러나 "1년간 지출 패턴이 어떻게 바뀌었나?", "식비가 매달 예산을 얼마나 초과했나?" 같은 중장기 인사이트를 얻을 화면이 없다. 반복 거래도 매월 고정만 가능 — 주간 구독 서비스나 일 단위 지출 규칙은 등록 불가. |
| **Solution** | (A) **리포트 탭 신규** — 연간 수입/지출/순자산 추이 + 월별 카테고리 바 차트 + 연간 합계 카드 + 예산 vs 실제 비교. (B) **반복 주기 확장** — schema v6에 recurrence_type(monthly/weekly/daily) + day_of_week 추가. isDue 순수 함수 확장. (C) **FR-67 청산** — 카테고리 자식 drag-reorder 구현 (~50 LOC). |
| **Function/UX Effect** | 5번째 "리포트" 탭 → 연도 선택 → 연간 요약 카드 + 12개월 라인 차트 + 월별 카테고리 바 + 예산 비교 섹션. 반복 거래 설정 시 매월/매주/매일 선택 가능. 카테고리 설정에서 소분류끼리 드래그 정렬. |
| **Core Value** | M4 = 자동+통제 → **M5 = 인사이트+완결**. 연간 흐름을 시각화해 재무 의사결정의 근거를 마련. 반복 주기 다양화로 실생활 고정비 100% 커버. M5 이후 앱은 기능적으로 완결 상태. |

---

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 단기 통제(M4) 이후 중장기 인사이트 확보 + 반복 거래 주기 다양화 → 앱 기능 완결 |
| **WHO** | 본인 1인 (M1~M4 사용자). 2~3개월 데이터 누적, 연간 추이 파악 니즈 발생 |
| **RISK** | (1) 리포트 쿼리 성능 — 12개월 × N카테고리 집계 (2) recurrence_type 추가 시 isDue 로직 복잡도 (3) v5→v6 마이그레이션 안전성 (4) 5번째 탭 추가 시 네비게이션 레이아웃 |
| **SUCCESS** | 리포트 탭에서 연간 수입/지출 라인 + 월별 카테고리 바 확인 / 매주·매일 반복 거래 등록 / FR-67 drag-reorder 작동 |
| **SCOPE** | FR-67 backlog + 반복 주기(weekly/daily) + 리포트 탭(4종 차트). Sheets 동기화 현재 유지, Release build 제외. |

---

## 1. User Intent Discovery

### 1.1 Core Problem (M4 사용 후 발견)

M4까지 구현한 것:
- 반복 거래 도래 알림 (매월 N일)
- 카테고리별 월 예산 + 분석 탭 오버레이
- 12개월 주간 라인 차트, 도너츠 차트

**여전히 남은 불편:**
- "올해 총 지출이 작년보다 나아졌나?" → 월별 데이터는 있지만 연간 비교 화면 없음.
- "식비가 매달 얼마씩 초과하는 패턴?" → 분석 탭은 이번 달만 보여줌.
- "넷플릭스(매월) + 유튜브 프리미엄(매월) + 헬스장(매월) 외에 주간 정기 지출이 있다" → 매월만 지원.
- 카테고리 설정에서 소분류 순서 변경 불가 (FR-67, M3→M4→M5 3회 이월).

### 1.2 Target Users

| User Type | Usage Context | Key Need |
|-----------|---------------|----------|
| 본인 (M4 사용자, 2-3개월 데이터 누적) | 연간 재무 흐름 파악 + 주간 정기 지출 등록 | 연간 추이 시각화, 반복 주기 다양화 |

### 1.3 Success Criteria

- [ ] **리포트 탭 표시**: 5번째 탭에서 선택한 연도의 연간 요약 카드 확인 가능
- [ ] **월별 추이 차트**: 12개월 수입/지출/순자산 라인 차트 정상 렌더링
- [ ] **월별 카테고리 차트**: 12개월 카테고리별 지출 바 차트 (또는 heatmap) 표시
- [ ] **예산 vs 실제 비교**: M4 예산 데이터와 월별 실제 지출 비교 테이블
- [ ] **weekly/daily 반복 등록**: RecurringRuleFormSheet에서 매주/매일 선택 + isDue 정확
- [ ] **FR-67 drag-reorder**: 카테고리 설정에서 소분류끼리 드래그 정렬 작동

### 1.4 Constraints

| Constraint | Details | Impact |
|------------|---------|--------|
| Sheets 동기화 미변경 | one-way push 유지. 리포트/반복주기 Sheets sync 미포함 | Low |
| Release build 미포함 | M6 또는 별도 사이클로 분리 | Low |
| 리포트 쿼리 성능 | 12개월 집계 — 데이터 적을 경우 문제 없음. 추후 캐시 검토 | Medium |
| Schema v6 | recurring_rules에 2개 컬럼 추가 (v5→v6) | Medium |
| 5탭 네비게이션 | GoRouter ShellRoute 수정 필요 | Low |

---

## 2. Alternatives Briefly Considered

### 2.1 리포트 위치

| 옵션 | 장단점 | 결정 |
|------|--------|------|
| **5번째 탭 추가 (선택)** | 항상 접근 가능. 전용 공간. | ✅ |
| 분석 탭 서브화면 | 탭 수 유지. 단 분석 탭 과밀화 우려. | ❌ |
| 설정 내 서브화면 | 연간 리포트는 핵심 기능 — 설정에 두기엔 낮은 접근성 | ❌ |

### 2.2 반복 주기 모델

| 옵션 | 장단점 | 결정 |
|------|--------|------|
| **recurrence_type 추가 (선택)** | 기존 day_of_month 컬럼 유지 + day_of_week nullable 추가. v5→v6 단순 addColumn 2건. | ✅ |
| 새 테이블 분리 | 더 유연하지만 과도한 스키마 변경 | ❌ |
| recurrence_interval + unit | 1-week / 2-week 등 지원 가능. M5 필요 없음 | M6 |

### 2.3 리포트 데이터 레이어

| 옵션 | 장단점 | 결정 |
|------|--------|------|
| **ReportRepository 신규 (선택)** | AnalyticsRepository와 분리. 리포트 전용 집계 쿼리. | ✅ |
| AnalyticsRepository 확장 | 단일 파일 비대화 우려 (이미 복잡함) | ❌ |

---

## 3. YAGNI Review

### 3.1 Included (M5 Must-Have)

- [ ] **FR-67**: categories_screen.dart 소분류 drag-reorder 구현
- [ ] **Schema v6**: recurring_rules에 recurrence_type(TEXT, default 'monthly') + day_of_week(INT nullable) 추가
- [ ] **v5→v6 마이그레이션**: addColumn ×2
- [ ] **RecurringRule.isDue 확장**: weekly/daily 분기 추가
- [ ] **RecurringRuleFormSheet 수정**: recurrence_type picker + day_of_week picker(weekly 시)
- [ ] **reports/ feature 신규**: ReportRepository + ReportsScreen + 4개 위젯
- [ ] **ReportRepository.monthlyTrend()**: 12개월 수입/지출/순자산 집계
- [ ] **ReportRepository.monthlyCategorySpend()**: 12개월 카테고리별 지출 집계
- [ ] **ReportRepository.yearSummary()**: 연간 합계 + 전년 비교
- [ ] **ReportRepository.budgetVsActual()**: M4 예산 대비 실제 지출 (월별)
- [ ] **MonthlyTrendChart**: 수입/지출/순자산 라인 차트 (fl_chart 재사용)
- [ ] **MonthlyCategoryBarChart**: 월별 카테고리 지출 바 차트
- [ ] **YearSummaryCard**: 연간 수치 카드 + 전년 비교
- [ ] **BudgetComparisonSection**: 예산 vs 실제 비교 테이블
- [ ] **5번째 탭**: 라우터 + 네비게이션 바 업데이트
- [ ] **Migration test**: v5→v6 in-memory 테스트 추가

### 3.2 Deferred (M6+)

| Feature | Reason | Revisit |
|---------|--------|---------|
| Release build (AAB/Keystore) | 기능 완성 후 별도 사이클 | M6 |
| 반복 간격 커스터마이징 (2주마다 등) | M5는 daily/weekly/monthly 3종으로 충분 | M6 |
| 리포트 PDF/Sheets 내보내기 | Sheets one-way push로 커버 | M6 |
| 리포트 커스텀 기간 (분기별 등) | 연간/월별로 충분 | M6 |
| 예산 기간 커스터마이징 | M5 scope 초과 | M6 |

### 3.3 Removed (Won't Do)

| Feature | Reason |
|---------|--------|
| 양방향 Sheets pull | 로컬 데이터 단방향으로 충분. 복잡도 대비 가치 낮음 |
| 달성 배지 / 게이미피케이션 | 기능 완결 후 검토. M5 핵심 아님 |

---

## 4. Scope

### 4.1 In Scope (M5)

- FR-67 backlog 청산 (카테고리 소분류 drag-reorder)
- Schema v6: recurring_rules recurrence_type + day_of_week
- isDue 로직 weekly/daily 분기 + FormSheet picker
- reports/ feature: ReportRepository 4종 쿼리 + ReportsScreen + 4종 위젯
- 5번째 "리포트" 탭 라우팅

### 4.2 Out of Scope (M5)

- Sheets 동기화 변경 (one-way push 현재 유지)
- Release build
- 반복 간격 커스터마이징
- 리포트 PDF 내보내기

---

## 5. Requirements

### 5.1 Functional Requirements (M5 신규)

| ID | Requirement | Priority | Status |
|----|-------------|:--------:|:------:|
| FR-68 | categories_screen.dart `_TopLevelTile` children을 `ReorderableListView`로 교체 + `CategoryRepository.reorder(childIds)` 재사용 (M4 backlog FR-67 완료) | Medium | Pending |
| FR-69 | `recurring_rules` 테이블에 `recurrence_type TEXT NOT NULL DEFAULT 'monthly'` + `day_of_week INTEGER` (nullable, 1=Mon~7=Sun) 추가. v5→v6 마이그레이션. | High | Pending |
| FR-70 | `RecurringRule.isDue(today)` 확장 — recurrenceType별 분기: monthly(기존 로직), weekly(요일 일치 + 이번주 미처리), daily(오늘 미처리) | High | Pending |
| FR-71 | `RecurringRuleFormSheet` 수정 — recurrence_type picker (매월/매주/매일) + weekly 선택 시 day_of_week picker (월~일) | High | Pending |
| FR-72 | `ReportRepository.monthlyTrend(year)` → `List<MonthlyTrend>` (year, month, income, expense, netAssets) — 12개월 집계 | High | Pending |
| FR-73 | `ReportRepository.monthlyCategorySpend(year)` → `List<MonthlyCategorySpend>` (year, month, categoryId, categoryName, amount) | High | Pending |
| FR-74 | `ReportRepository.yearSummary(year)` → `YearSummary` (income, expense, savings, savingsRate, prevYear 비교) | High | Pending |
| FR-75 | `ReportRepository.budgetVsActual(year)` → `List<BudgetVsActual>` (categoryId, categoryName, monthlyBudget, monthlySpent 12개월) | Medium | Pending |
| FR-76 | `ReportsScreen` 신규 — 연도 선택 헤더 + 4개 섹션 (연간 요약 / 월별 추이 / 카테고리 바 / 예산 비교) | High | Pending |
| FR-77 | `MonthlyTrendChart` 위젯 — 수입(green)/지출(red)/순자산(blue) 3선 라인 차트. fl_chart LineChart. | High | Pending |
| FR-78 | `MonthlyCategoryBarChart` 위젯 — 월별 카테고리 지출 GroupedBarChart (상위 5개 카테고리 + 기타). | High | Pending |
| FR-79 | `YearSummaryCard` 위젯 — 총수입/총지출/저축률 3칸 + 전년 대비 delta (있으면 표시, 없으면 "-"). | High | Pending |
| FR-80 | `BudgetComparisonSection` 위젯 — 예산 설정된 카테고리별 12개월 평균 지출 vs 예산 바. 예산 미설정 시 섹션 숨김. | Medium | Pending |
| FR-81 | GoRouter ShellRoute 5번째 탭 추가 (`/reports`), BottomNavigationBar 업데이트. 리포트 아이콘: `Icons.bar_chart_rounded`. | High | Pending |
| FR-82 | Migration test 추가: v5→v6 (recurrence_type default 값 확인, day_of_week nullable 확인, 기존 recurring_rules 데이터 보존) | Medium | Pending |

### 5.2 Non-Functional Requirements

| Category | Criteria | Measurement |
|----------|----------|-------------|
| 리포트 쿼리 성능 | monthlyTrend(12개월) ≤ 500ms | 월별 aggregate 쿼리. 데이터 소량이므로 큰 문제 없음 |
| isDue 확장 | 기존 monthly 로직 100% 유지 | 기존 5건 단위 테스트 여전히 pass |
| v5→v6 마이그레이션 | ≤ 200ms (addColumn ×2, O(1)) | in-memory test |

---

## 6. Success Criteria (Definition of Done)

### 6.1 M5 DoD

- [ ] FR-68~82 구현 (전체 또는 명시적 deferred 표시)
- [ ] flutter analyze 0 issues
- [ ] flutter test 모두 통과 (기존 101 + M5 신규 ~12 = ~113건 예상)
- [ ] isDue weekly/daily 단위 테스트 작성 + pass
- [ ] ReportRepository 통합 테스트 최소 3건 pass
- [ ] 리포트 탭 수동 검증: 연도 전환 시 차트 데이터 갱신 확인

### 6.2 Quality Criteria

- [ ] flutter analyze 0 warnings
- [ ] isDue pure function 단위 테스트 총 9건 이상 (monthly 5 + weekly 2 + daily 2)
- [ ] ReportRepository 쿼리 각 1건 이상 통합 테스트

---

## 7. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| 리포트 쿼리 성능 (12개월 × 카테고리 집계) | Medium | Low | 월별 순차 쿼리 → 배치 쿼리로 최적화. M4 budgetOverlay 3-query 패턴 재사용. |
| isDue weekly 주 경계 계산 오류 | High | Medium | DateTime weekday + 주 시작일 계산 → 단위 테스트 2건 필수 (이번주 처리됨 / 지난주 처리됨). |
| fl_chart 5번째 탭 데이터 없을 때 빈 상태 | Low | High | 데이터 없으면 "아직 거래 데이터가 없습니다" empty state 표시. null-safe. |
| 5탭 네비게이션 바 공간 부족 | Low | Medium | label 짧게 (홈/기록/분석/리포트/설정). 실기기 테스트로 확인. |
| MonthlyCategoryBarChart 카테고리 많을 때 | Low | Low | 상위 5개만 표시 + "기타" 카테고리로 합산. 범례 생략 가능. |

---

## 8. Architecture Considerations

### 8.1 변경 없는 부분

| 영역 | M4 결정 유지 |
|------|------------|
| 회계 모델 | 4-type Tx (변경 없음) |
| Sheets 동기화 | one-way push (변경 없음) |
| 상태관리 | Riverpod 2.x |
| 기존 기능 전체 | M1~M4 코드 수정 최소화 |

### 8.2 신규 모듈

```
lib/
├── core/db/
│   ├── tables.dart                                    # ✏️ recurring_rules에 2개 컬럼 추가
│   ├── app_database.dart                              # ✏️ schemaVersion=6, v5→v6 호출
│   └── migrations/
│       └── v5_to_v6.dart                              # 🆕 addColumn ×2
├── features/
│   ├── dashboard/data/
│   │   └── recurring_rule_repository.dart             # ✏️ isDue 확장 (weekly/daily)
│   ├── dashboard/ui/
│   │   └── recurring_rule_form_sheet.dart             # ✏️ recurrence_type picker 추가
│   ├── categories/ui/
│   │   └── categories_screen.dart                     # ✏️ FR-68: 소분류 ReorderableListView
│   └── reports/                                       # 🆕 신규 feature
│       ├── data/
│       │   └── report_repository.dart                 # 🆕 4종 쿼리 메서드
│       └── ui/
│           ├── reports_screen.dart                    # 🆕 5번째 탭 메인 화면
│           ├── monthly_trend_chart.dart               # 🆕 라인 차트 위젯
│           ├── monthly_category_bar_chart.dart        # 🆕 바 차트 위젯
│           ├── year_summary_card.dart                 # 🆕 연간 요약 카드
│           └── budget_comparison_section.dart         # 🆕 예산 vs 실제 섹션
├── app/
│   ├── providers.dart                                 # ✏️ report providers 추가
│   └── router.dart                                    # ✏️ /reports 탭 + ShellRoute 5탭
```

**신규 파일**: 7개 / **수정 파일**: 7개 / 예상 LOC: ~900

### 8.3 Schema v6 Delta

```dart
// tables.dart — RecurringRules 수정
// Design Ref: §3 — v6 delta. 매월 외 매주/매일 지원.

class RecurringRules extends Table {
  // ... 기존 컬럼 유지 ...

  /// 'monthly' | 'weekly' | 'daily'
  TextColumn get recurrenceType =>
      text().withDefault(const Constant('monthly'))();

  /// Dart DateTime.weekday: 1=Mon ~ 7=Sun. weekly 시만 사용. nullable.
  IntColumn get dayOfWeek => integer().nullable()();
}
```

```dart
// v5_to_v6.dart
class V5ToV6 {
  const V5ToV6._();
  static Future<void> apply(Migrator m, AppDatabase db) async {
    await m.addColumn(db.recurringRules, db.recurringRules.recurrenceType);
    await m.addColumn(db.recurringRules, db.recurringRules.dayOfWeek);
  }
}
```

### 8.4 isDue 확장 로직

```dart
bool isDue(DateTime today) {
  if (!isActive) return false;

  switch (recurrenceType) {
    case 'daily':
      if (lastConfirmedAt == null) return true;
      final lc = lastConfirmedAt!;
      return !(lc.year == today.year &&
               lc.month == today.month &&
               lc.day == today.day);

    case 'weekly':
      if (dayOfWeek != today.weekday) return false; // 1=Mon~7=Sun
      if (lastConfirmedAt == null) return true;
      // 이번 주 월요일 (주 시작) 비교
      final todayMon = today.subtract(Duration(days: today.weekday - 1));
      final lcMon = lastConfirmedAt!.subtract(
          Duration(days: lastConfirmedAt!.weekday - 1));
      return todayMon.isAfter(lcMon);

    default: // 'monthly'
      if (dayOfMonth > today.day) return false;
      if (lastConfirmedAt == null) return true;
      final lc = lastConfirmedAt!;
      return lc.year < today.year ||
          (lc.year == today.year && lc.month < today.month);
  }
}
```

### 8.5 ReportsScreen 구조

```
ReportsScreen
├── 연도 선택 헤더 (< 2025  2026  > — 미래 비활성)
├── YearSummaryCard (총수입 / 총지출 / 저축률 + 전년 delta)
├── MonthlyTrendChart (수입/지출/순자산 라인, 12개월)
├── MonthlyCategoryBarChart (월별 카테고리 지출 바)
└── BudgetComparisonSection (예산 설정된 카테고리만, 없으면 숨김)
```

---

## 9. Convention Prerequisites

M1~M4와 동일 (Flutter lints + Riverpod naming + Drift naming + 한국어 UI). 추가:

- `recurrenceType`: String 값은 `'monthly'` / `'weekly'` / `'daily'` 소문자 고정. enum 미사용 (Drift TEXT 컬럼).
- `isDue` 단위 테스트: monthly 5건 (기존) + weekly 2건 + daily 2건 = 9건 이상 필수.
- Report 쿼리는 `ReportRepository` 단일 클래스로 집중. `AnalyticsRepository` 수정 없음.
- fl_chart 이미 의존성 있음 (M1 도너츠 차트). `LineChart` + `BarChart` 추가 사용.

---

## 10. Milestones

| MS | 범위 | 핵심 작업 | 예상 |
|----|------|-----------|------|
| **M5.1 fr67-recurrence** | FR-68(소분류 drag) + FR-69~71(schema v6 + isDue 확장 + FormSheet picker) | categories_screen 소분류 ReorderableListView + addColumn ×2 + isDue switch 분기 + FormSheet recurrence picker | 2일 |
| **M5.2 report-infra** | FR-72~75(ReportRepository 4종) + FR-81(5탭 라우팅) + FR-82(migration test) | report_repository.dart 쿼리 메서드 + providers + router 5탭 + migration test | 2일 |
| **M5.3 report-ui** | FR-76~80(ReportsScreen + 4종 위젯) | YearSummaryCard + MonthlyTrendChart + MonthlyCategoryBarChart + BudgetComparisonSection + ReportsScreen 조립 | 3일 |

총 ~7일 (M4 ~9일보다 가벼움 — 신규 쿼리 집중, UI는 기존 fl_chart 재사용).

---

## 11. Next Steps

1. [ ] Plan 검토 후 → `/pdca design budget-tracker-m5`
2. [ ] M5.1부터 순서대로 구현 (`/pdca do budget-tracker-m5 --scope fr67-recurrence`)
3. [ ] M5 사이클 종료 → `/pdca analyze budget-tracker-m5` → `/pdca report budget-tracker-m5`

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-04-30 | Initial M5 plan — FR-67 backlog + 반복 주기 확장(weekly/daily, schema v6) + 리포트 탭 신규(5번째 탭, 4종 시각화). 3 milestones ~7일. | kyk@hunik.kr |
