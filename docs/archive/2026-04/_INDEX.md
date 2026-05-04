# Archive Index — 2026-04

| Feature | Cycle | Match Rate | Tests | Archived At | Path |
|---------|-------|:----------:|:-----:|-------------|------|
| budget-tracker-m4 | M4 | 95% | 101/101 | 2026-04-30 | [budget-tracker-m4/](budget-tracker-m4/) |

---

## budget-tracker-m4 Summary

- **What**: 반복 고정비 도래 알림(홈 배지) + 카테고리별 예산 한도 + 분석 탭 예산 오버레이
- **Schema**: v5 (recurring_rules + budgets 2개 신규 테이블)
- **Architecture**: Option A — Minimal (기존 dashboard/analytics 폴더 확장)
- **SC**: 5/5 달성 · FR 13/14 (FR-67 카테고리 자식 drag-reorder M5 이월)
- **Bug fixed**: `BudgetRepository.upsert` conflict target id→category_id
- **Sessions**: 5 (recurring-schema / recurring-mgmt / budget-setup / budget-analytics / migration-tests)
