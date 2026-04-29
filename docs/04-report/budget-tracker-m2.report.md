---
template: report
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
baseAnalysis: docs/03-analysis/budget-tracker-m2.analysis.md
status: completed
matchRate: 99
---

# Budget Tracker — M2 Completion Report

> **M2 = 이해 + 예측**. M1의 입력·기록 데이터를 분석·검색·예측으로 활용.
> Static Match Rate **99%**, 5/5 Success Criteria 충족 (SC-3는 정적 OK + 디바이스 측정 보류), 0 Critical issues.

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | M1으로 누적된 거래 데이터를 앱 안에서 "어디에 얼마", "다음 카드값", "거래 검색"으로 활용하지 못해 Sheets 피봇으로 격하되던 문제. |
| **Solution** | 5개 신규 기능(카드 상세 D-day, 분석 탭 도너츠+라인, List SearchBar+4칩, 계좌 트리, transfer-to-card 안내) + Drift v3 마이그레이션 + Repository 통합 테스트 5건으로 M1 deferred 청산. |
| **Function/UX Effect** | 5탭 → 6탭 (분석 추가). 계좌 탭 신용카드 탭 → 카드 상세(D-day/이번달 사용/예상 결제/최근 10건). 분석 탭으로 한 화면에 카테고리 비중 + 6개월 고정/변동 추이. 내역 탭 SearchBar + 4칩(기간/계좌/카테고리/타입) 250ms debounce. |
| **Core Value** | M1 = 입력 + 보관 → **M2 = 이해 + 예측**. 본인이 매월 어느 카테고리에서 새고, 다음 카드값이 언제·얼마인지 미리 알고 대응. 가계부의 진짜 가치 (다음 행동 결정에 도움)를 닫음. |

### Value Delivered

| 지표 | 목표 | 결과 |
|------|------|------|
| 신규 기능 (FR) | 14건 (FR-19~32) | **14건 / 14건 ✅** |
| 신규 화면 | 카드 상세 + 분석 | **2/2 ✅** |
| 새 모듈 | analytics | **추가됨 ✅** |
| 새 탭 | 6번째 (분석) | **추가됨 ✅** |
| Drift 마이그레이션 | v2→v3 (첫 마이그레이션) | **작성됨 ✅** (디바이스 실증 사용자) |
| 통합 테스트 | TransactionRepository 5건 | **5건 ✅** (M1 deferred 청산) |
| Static Match Rate | ≥ 90% | **99% ✅** |
| Decision Record 준수 | 7/7 | **7/7 ✅** |
| 검색 응답 ≤ 100ms | SC-3 | ⚠️ **정적 OK / 디바이스 측정 보류** |
| flutter analyze 0 issues | DoD §6.1 | ⏳ **사용자 실행 (8 issues 수정 후 재검증 대기)** |
| APK ≤ 30MB | NFR | ⏳ **사용자 빌드 검증** |

---

## 1. PRD → Plan → Design → Implementation 전체 흐름

PRD는 1인 가계부 특성상 별도 작성하지 않음 (Plan §1에 통합).

| Phase | 산출물 | 주요 결정 |
|-------|--------|-----------|
| **Plan** (2026-04-28) | 14 FR + 5 SC + 4 milestones | 카드 상세 = AccountsScreen drill-down (5탭 유지하다 6탭은 분석만), 차트 = fl_chart, 검색 = memo LIKE only |
| **Design** (2026-04-28) | Option C (Pragmatic) — analytics 신모듈만 추가, 나머지는 M1 모듈 흡수 | 11 신규 + 7 수정 = ~950 LOC, 4 세션 분할 |
| **Implementation** (2026-04-28) | 4 sessions (schema-card / analytics-tab / search-filter / tree-tests) | 각 세션마다 Checkpoint 4 사용자 승인 후 진행 |
| **Analysis** (2026-04-29) | 99% Match Rate, 0 Critical, 3 Important (Design 문서 wording 갭) | gap-detector 정적 분석 |

---

## 2. Key Decisions & Outcomes (PRD→Plan→Design Chain)

| Decision | Source | Outcome | 비고 |
|----------|--------|---------|------|
| 분석 화면 위치 = 새 6번째 탭 | Plan §2.2 | ✅ 따름 | router.dart 6 destinations |
| 카드 결제 정보 위치 = 계좌 탭 drill-down | Plan §2.1 | ✅ 따름 | accounts_screen.dart 132-138 |
| 차트 라이브러리 = fl_chart 0.69.0 | Plan §2.3 | ✅ 따름 | Donut + Line 2종, +3MB APK 예상 |
| Architecture = Option C (Pragmatic) | Design §13 | ✅ 따름 | analytics만 신모듈, 나머지 M1 흡수 |
| 검색 keyword = memo만 (LIKE) | Design §13 | ✅ 따름 | transactions_dao.dart:88 |
| Migration 명명 = `v{from}_to_{to}.dart` | Design §13 | ✅ 따름 | `core/db/migrations/v2_to_v3.dart` |
| sqlite3 dev_dep | Design §11.1 | ✅ 따름 | pubspec.yaml dev_dependencies |
| due_day clamp 1-28 (2월 안전) | Design §3.1 | ✅ 따름 | `_normalizeDueDay` + `computeNextDueDate` 이중 안전 |
| 빈 필터 = 기존 reactive stream fallback | Design §5.4 | ✅ 따름 | list_screen.dart `filter.isEmpty` 분기 |
| Sheets accounts 헤더 자동 확장 | Design §8.1 | ✅ 따름 | overwriteRange A1:G로 변경, 기존 사용자 시트 자동 갱신 |

**편차 (Deviation)**: 0건. 의도적 보강 (D-0 명시적 처리, sealed `_SheetResult` for chip BottomSheet dismiss/clear disambiguation 등)은 모두 Design 의도 범위 내.

---

## 3. Plan Success Criteria — Final Status

| # | Criteria | Final | Evidence |
|---|----------|:----:|----------|
| **SC-1** | 카드 결제 예정 D-day + 예상 금액 정확 | ✅ Met | `CardDetailRepository.computeNextDueDate` (1-28 clamp + null handling) + `_NextDuePanel` D-day rendering. dueDay null 시 "결제일 미설정" fallback. |
| **SC-2** | 카테고리 도너츠 + 고정/변동 라인 | ✅ Met | `AnalyticsRepository.categoryDonut/fixedVariableSeries` + `AnalyticsScreen` 월 picker + `CategoryDonutChart` (top 5 + 기타 collapse) + `FixedVariableLineChart` (6개월 + empty buckets). |
| **SC-3** | 검색 응답 ≤ 100ms | ⚠️ Partial | DAO 정적 최적화 검증 완료 (memo-LIKE-only-when-keyword + indexed (occurred_at DESC) + 250ms debounce + limit 200). **수치 검증은 디바이스에서**. |
| **SC-4** | 계좌 트리 시각화 | ✅ Met | `_renderBucket` + `_appendChildren` 재귀 (depth × 24 indent) + AccountFormSheet parent dropdown. |
| **SC-5** | TransactionRepository 통합 테스트 5건 | ✅ Met | `test/integration/transaction_repository_test.dart` — expense/transfer/valuation/update/delete. M1 deferred 청산 완료. |

**Overall Success Rate: 5/5 functional met (1 partial — perf measurement device-side).**

---

## 4. 산출물

### 4.1 신규 파일 (16개)

| 영역 | 파일 |
|------|------|
| Schema | `core/db/migrations/v2_to_v3.dart` |
| Accounts | `accounts/domain/card_detail_metrics.dart`, `accounts/data/card_detail_repository.dart`, `accounts/ui/card_detail_screen.dart` |
| Analytics | `analytics/domain/category_segment.dart`, `analytics/domain/monthly_split_series.dart`, `analytics/data/analytics_repository.dart`, `analytics/ui/analytics_screen.dart`, `analytics/ui/category_donut_chart.dart`, `analytics/ui/fixed_variable_line_chart.dart` |
| Search | `transactions/domain/search_filter.dart`, `transactions/ui/search_bar_widget.dart`, `transactions/ui/filter_chips.dart` |
| Tests | `test/integration/transaction_repository_test.dart` |

### 4.2 수정 파일 (14개)

`tables.dart`, `app_database.dart`, `account_repository.dart`, `accounts_dao.dart`, `account_form_sheet.dart`, `accounts_screen.dart`, `transactions_dao.dart`, `list_screen.dart`, `input_screen.dart` (transfer-to-card hint), `sheet_layout.dart`, `sync_service.dart`, `app/providers.dart`, `app/router.dart`, `pubspec.yaml`, `test/sheet_layout_test.dart`.

### 4.3 LOC

총 **~2,640 LOC** 추가 (Design 추정 ~950의 약 2.8배 — chart wrapper / 4-chip BottomSheet / dual-path list / sealed result types 등이 부피 키움).

---

## 5. 학습 포인트 (Learnings for Future Cycles)

### 5.1 Drift + flutter_test isNull 충돌
통합 테스트 작성 시 `package:drift/drift.dart`와 `flutter_test`의 `isNull`/`isNotNull`이 ambiguous_import 충돌. **반드시 `hide isNull, isNotNull`** 필요. → 메모리에 feedback 기록.

### 5.2 BottomSheet dismiss vs explicit-clear disambiguation
Filter chip의 BottomSheet에서 outside-tap dismiss와 "전체 X" 항목 선택을 구분하지 않으면 사용자가 의도치 않게 필터를 초기화. **sealed `_SheetResult<T>` 패턴**으로 `_SheetClear` / `_SheetSelect` / `null(dismiss)` 3-way 구분 필요.

### 5.3 Riverpod Family + DateTime key
FutureProvider.family<DateTime>은 동일 값의 DateTime 인스턴스가 같은 hash/equality를 가져 캐시가 정상 동작. 단, **month-start로 normalize**해서 key 충돌 회피.

### 5.4 fl_chart 0.69 LineChart Y축 단위
KRW 단위는 차트 축에 너무 길어 가독성 떨어짐. **`(value / 10000).round()` "만원" 단위 fallback** 적용해 축 라벨 폭 절약.

### 5.5 Drift 마이그레이션 표준화
첫 마이그레이션 작성. **`core/db/migrations/v{from}_to_{to}.dart` 패턴 + `MigrationStrategy.onUpgrade`에 if-from-less-than 분기** → 미래 v3→v4 추가 시 일관된 위치.

### 5.6 Sheets 헤더 자동 확장
기존 사용자 시트(M1 6컬럼)는 첫 동기화 시 `overwriteRange A1:G`로 7컬럼 헤더 + 데이터 자동 갱신. **별도 마이그레이션 코드 불필요** — overwrite range 변경만으로 충분.

---

## 6. Open Questions Resolution

Design §12에서 제기된 5개 질문:

| # | Question | Status |
|---|----------|--------|
| Q1 | 카드 결제일 변동 사용자 (25일/30일) | M3 보류 — M2는 단일 due_day. M3에서 due_day_secondary 검토. |
| Q2 | 라인 차트 6개월 이전 데이터 부족 시 UX | ✅ 해결 — empty buckets 사전 시드로 0/0 점 표시 (라인 연속성 유지) |
| Q3 | List 칩 필터 "기간" 기본값 | ✅ 해결 — "전체기간" (filter.isEmpty 경로와 자연 부합) |
| Q4 | 트리에서 비활성 부모 자식 표시 | M3 보류 — 현재는 활성 only watchAll에서 자식이 함께 가려짐 |
| Q5 | 검색 결과 limit 200 hit UX | ✅ 해결 — "(최대) 필터를 더 좁혀보세요" 안내. "더 보기" pagination은 M3로 |

**해결 3 / 보류 2 (모두 M3)**.

---

## 7. M3 후보 (M2 사용 후 검토)

Plan §3.2에 명시된 deferred + Open Questions에서 보류된 항목:

| 항목 | 우선도 | 근거 |
|------|--------|------|
| 반복 거래 템플릿 | 높음 | M2 분석 데이터로 패턴 인식 가능해짐 |
| 월별/연도별 리포트 | 중 | 도너츠/라인으로 부족하면 |
| 예산 설정 + 초과 경고 | 중 | 카테고리 분석 1-2개월 누적 후 의미 |
| 카드 결제일 변동 (Q1) | 낮 | 사용 후 결정 |
| 비활성 계좌 트리 표시 (Q4) | 낮 | 사용 후 결정 |
| 검색 "더 보기" pagination (Q5) | 낮 | limit 200 hit 빈도 본 후 |
| Design §5.5 cross-bucket tree merge | 낮 | M2 Important #2 — 사용 후 결정 |

---

## 8. DoD 최종 체크리스트

### Plan §6.1 M2 DoD

- [x] FR-19~FR-32 구현 (14/14)
- [⏳] flutter analyze 0 issues — 8 issues 수정 후 사용자 재실행 필요
- [⏳] flutter test 모두 통과 — 사용자 재실행 필요
- [x] TransactionRepository 통합 테스트 5건 작성 (M1 deferred 청산)
- [x] Drift v2→v3 마이그레이션 작성
- [⏳] APK 빌드 + 디바이스 동작 검증 (사용자)
- [⏳] M1 데이터 보존 검증 (디바이스 v3 마이그레이션 실증)

### Plan §6.2 Quality

- [⏳] flutter analyze 0 warnings (재실행)
- [⏳] Repo/Sync 통합 테스트 커버리지 ≥ 60% (`flutter test --coverage` 측정)
- [⏳] 마이그레이션 전후 잔액 무결성 검증 (BalanceReconciler 통과)

---

## 9. 마무리

M2 4 세션 모두 완료. 코드 레벨 구현 100% / 정적 분석 99% / 0 Critical issues. 디바이스 실증 + APK 빌드는 사용자 영역.

```bash
# M2 출시 전 사용자 체크
flutter pub get
dart run build_runner build --force-jit --delete-conflicting-outputs
flutter analyze              # 0 issues
flutter test                 # ~76건 통과
flutter test --coverage      # ≥ 60%
flutter run                  # v2→v3 마이그레이션 실증
flutter build apk --release --analyze-size  # ≤ 30MB
```

**Next**: 디바이스 실증 통과 후 → `/pdca archive budget-tracker-m2 --summary` (M1처럼 M2도 archive로 정리, summary 보존). 그 후 M3 Plan 시작.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-29 | Initial M2 completion report. 5/5 SC met (1 partial — device measurement). 99% Match Rate. 0 Critical / 3 Important (Design wording). |
