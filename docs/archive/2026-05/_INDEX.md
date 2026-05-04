# Archive Index — 2026-05

| Feature | Cycle | Match Rate | Tests | Archived At | Path |
|---------|-------|:----------:|:-----:|-------------|------|
| budget-tracker-m5 | M5 | 99.5% | 37/37 | 2026-05-04 | [budget-tracker-m5/](budget-tracker-m5/) |

---

## budget-tracker-m5 Summary

- **What**: 연간 리포트 탭(4종 시각화) + 반복 거래 주기 확장(weekly/daily, schema v6) + FR-68 카테고리 소분류 drag-reorder
- **Schema**: v6 (recurring_rules에 recurrence_type + day_of_week 컬럼 추가)
- **Architecture**: Option A — analytics 폴더 확장 (신규 feature 디렉터리 없이 analytics/ui/ 하위 추가)
- **SC**: 6/6 달성 · FR 15/15 · Critical/Important Gap 0건
- **Post-archive fix**: 리포트 탭 → 홈 화면 카드 접근으로 변경 (5탭 → 4탭)
- **Sessions**: 3 (fr67-recurrence / report-infra / report-ui)
