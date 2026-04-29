---
template: analysis
version: 1.0
feature: budget-tracker-m3
cycle: M3
date: 2026-04-29
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.4.0"
level: Dynamic
basePlan: docs/01-plan/features/budget-tracker-m3.plan.md
baseDesign: docs/02-design/features/budget-tracker-m3.design.md
matchRate: 96
structuralRate: 100
functionalRate: 95
contractRate: 98
---

# Budget Tracker — M3 Static Gap Analysis

> **Static Match Rate: 96%** (≥ 90% threshold). 0 Critical / 2 Important / 1 Minor. 18/18 decisions kept.

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 일자별 시야 + 반복 입력 부담 제거 + 카테고리 해상도 향상 → 매일 사용성 + 분석 깊이 강화 |
| **WHO** | 본인 1인 (M1·M2 사용자, 1-2개월 데이터 누적) |
| **RISK** | Drift v3→v4 두 변경 동시 / Sheets 시트 신규 + tx 9→10 cols / 템플릿 amount NULL / 달력 month picker state 공유 / 카테고리 cascading UX |
| **SUCCESS** | 일별 합계 정확 / 템플릿 영구 재사용 / 카테고리 hierarchy로 도너츠 rollup + 입력 cascading / Sheets 동기화 / M2 데이터 0 손실 |
| **SCOPE** | 일별 달력 + 템플릿 CRUD/사용/sync + 카테고리 2-level + 마이그레이션 v4 |

---

## 1. Structural Rate — 100%

12 신규 + 9 수정 = 21 파일 모두 Design §2.1과 일치.

| 파일 | Status |
|------|:------:|
| `templates/{domain,data,ui}/*.dart` (6 신규) | ✅ |
| `categories/ui/{picker,form,categories}_screen.dart` (3 신규) | ✅ |
| `analytics/ui/daily_calendar.dart` (1 신규) | ✅ |
| `core/db/migrations/v3_to_v4.dart` (1 신규) | ✅ |
| `core/db/{tables,app_database}.dart` (✏️) | ✅ |
| `infrastructure/sheets/sheet_layout.dart` (✏️) | ✅ |
| `sync/service/{sync_service,sheets_sync_worker}.dart` (✏️) | ✅ |
| `analytics/data/analytics_repository.dart` (✏️ + dailyExpenseMap + rollup) | ✅ |
| `categories/data/category_repository.dart` (✏️ + hierarchy methods) | ✅ |
| `transactions/ui/{input_screen,filter_chips,input_form_state}.dart` (✏️) | ✅ |
| `settings/ui/settings_screen.dart` (✏️ 데이터 관리 섹션) | ✅ |
| `app/{router,providers}.dart` (✏️) | ✅ |
| `test/{integration,sheet_layout,analytics}_test.dart` (3 신규/보강) | ✅ |

---

## 2. Functional Rate — 95%

`templates_dao.dart`/`category_repository.dart`/`category_picker.dart`/`daily_calendar.dart` 등 핵심 컴포넌트는 모두 Design 사양과 일치.

**1건 부분 미충족**: Design §5.9 "자식도 drag-reorder (대분류 내에서)" — `categories_screen.dart`는 `topLevels`만 ReorderableListView, 자식은 단순 list. 자식 sortOrder는 백엔드 reorder API는 있으나 UI 미연결.

---

## 3. Contract Rate — 98%

### 3.1 Drift Schema (100%)
- schemaVersion=4 (`app_database.dart:36`)
- onUpgrade chained: `if(from<3) V2ToV3 + if(from<4) V3ToV4` (`app_database.dart:42-44`)
- v3_to_v4: `createTable(txTemplates) + addColumn(parentCategoryId)` (`v3_to_v4.dart:17-20`)
- TxTemplates schema 12개 컬럼 모두 일치
- `categories.parentCategoryId customConstraint = NULL REFERENCES categories(id) ON DELETE SET NULL` ✓

### 3.2 Sheets Layout (100%)
- txHeader 10 cols, D=`category_parent`, E=`category` (`sheet_layout.dart:22-33`)
- txAppendRange `transactions!A:J`, txIdSearchRange `transactions!I:I`, txIdColIdx=8 ✓
- templatesHeader 9 cols, range `templates!A1:I` ✓

### 3.3 SyncService (97%)
- 모든 contract 일치
- ⚠️ **기존 사용자 tx 시트 헤더 9→10 자동 갱신 로직 미구현** (Design §3.5 "M3.5 결정 필요" 항목 — 새 row append는 10 cols로 됨, 기존 헤더는 9 cols로 잔존). 신규 사용자 영향 없음.

---

## 4. Plan Success Criteria — 20 Met / 1 Partial / 0 Not Met

| FR | Status | Evidence |
|----|:------:|----------|
| FR-33~45 | ✅ Met | 13/13 모두 구현 |
| FR-46 (v3→v4 migration in-memory test) | ⚠️ Partial | dedicated migration test 없음. integration/unit tests는 v4 schema 직접 시작으로 동작 검증 (post-migration). Plan §11.3에 deferred 명시. |
| FR-47~53 | ✅ Met | 7/7 모두 구현 (categoryDonut rollup `analytics_repository.dart:50` `parentCategoryId ?? c.id` 정확) |

### DoD §6.1
- [x] FR 구현 21/21 (FR-46 partial)
- [⏳] flutter analyze / test / APK — 사용자 실행 (16 신규 tests 작성 완료)
- [x] TemplateRepository 통합 4건 + Category hierarchy 통합 4건 + dailyExpenseMap 6 + categoryDonut rollup 2 = 16 신규

---

## 5. Decision Record Compliance — 18/18 = 100%

| 결정 | Status |
|------|:------:|
| Architecture Option C (Pragmatic) | ✅ |
| 달력 위치 분석 탭 통합 | ✅ |
| 달력 expense type만 | ✅ |
| 달력 셀 텍스트 + heatmap | ✅ |
| Heatmap (amount/max).clamp(0.05, 0.7) | ✅ |
| 템플릿 관리 = 설정 sub | ✅ |
| 템플릿 amount nullable | ✅ |
| 템플릿 정렬 = sortOrder + lastUsedAt | ✅ |
| 템플릿 occurredAt 오늘 default | ✅ |
| Sheets one-way push | ✅ |
| Migration v{n}_to_{m}.dart 명명 | ✅ |
| 카테고리 2-level only (setParent enforces) | ✅ |
| 카테고리 시드 17개 모두 parent NULL | ✅ |
| 카테고리 관리 = 설정 sub | ✅ |
| CategoryPicker cascading 2-step | ✅ |
| 분석 도너츠 leaf→parent rollup | ✅ |
| Sheets tx category 2-cols 분리 | ✅ |
| ON DELETE SET NULL | ✅ |

---

## 6. Critical / Important Issues

### 🟡 Important #1 — FR-46 dedicated migration test 부재

- **Severity**: Important (DoD 명시 요건)
- **Confidence**: 100% — `test/migration/` 디렉터리 없음
- **Impact**: M2→M3 마이그레이션 회귀 자동 감지 불가. 디바이스 실증으로 커버 가능
- **Mitigation**: Plan §11.3 deferred 명시. M4 첫 작업으로 Drift `migration_runner` 도입 권장
- **Recommendation**: 디바이스에서 v3 데이터 가진 채 v4 auto-migrate 동작 검증으로 보충

### 🟡 Important #2 — 카테고리 자식 drag-reorder UI 미구현

- **Severity**: Important — Design §5.9 사양 미충족
- **Confidence**: 95% — `categories_screen.dart`는 대분류만 ReorderableListView
- **Impact**: 자식 수 늘면 picker 가독성 저하. 백엔드 `CategoryRepository.reorder`는 자식 ids도 받을 수 있어 UI만 추가 필요
- **LOC**: ~30줄 nested ReorderableListView
- **Recommendation**: 이번 사이클 후속 작은 작업 또는 M4 deferred

### 🔵 Minor — `_DayCell.onTap` 항상 호출

- **Severity**: Minor (UX, not functional)
- **Confidence**: 100% — `daily_calendar.dart:142` `hasAmount ? onTap : onTap` 의도 모호
- **Impact**: 0원 셀 탭해도 setDateRange + /list로 가서 빈 결과 표시. Design §5.1 "0원 셀 = 그날 거래 0건 확인용"과 일치하므로 의도된 동작
- **Recommendation**: 코멘트 명시 또는 삼항 제거 (단순 `onTap: onTap`). 기능 영향 없음

---

## 7. Static Match Rate

```
Structural × 0.2 = 100 × 0.2 = 20.0
Functional × 0.4 =  95 × 0.4 = 38.0
Contract   × 0.4 =  98 × 0.4 = 39.2
─────────────────────────────────────
Overall                       = 97.2 → 96%
```

---

## 8. Runtime Verification (사용자 실행)

### 작성된 테스트 (16건 + sheet_layout 보강)

| File | Tests | FR Coverage |
|------|------:|-------------|
| `test/sheet_layout_test.dart` (✏️) | ~10 cases | FR-43, FR-45 |
| `test/integration/template_repository_test.dart` (🆕) | 4 | FR-34 |
| `test/integration/category_hierarchy_test.dart` (🆕) | 4 | FR-48, FR-53 |
| `test/analytics_repository_test.dart` (🆕) | 8 (6+2) | FR-39, FR-51 |

UI/Widget 테스트는 작성 안 함 — 디바이스 실증으로 커버 (FR-35, 36, 37, 40, 42, 49, 50).

### 사용자 실행 명령

```bash
dart run build_runner build --force-jit --delete-conflicting-outputs
flutter analyze
flutter test                     # M1 63 + M2 ~13 + M3 16 신규 ≈ 92건
flutter build apk --release --analyze-size

# 디바이스 시나리오:
# 1) M2 디바이스 (v3 db) → APK 설치 → 자동 v4 마이그레이션 → 데이터 0 손실
# 2) 설정 → 카테고리 관리 → 식비 expand → 점심 추가 (parent=식비)
# 3) 입력 → 카테고리 picker [식비] 탭 → 소분류 [점심] 선택
# 4) 분석 탭 → 달력 → 셀 탭 → 내역 자동 전환 + 그 날짜 필터
# 5) 분석 도너츠 → 점심값이 식비로 rollup
# 6) 설정 → 동기화 → templates 시트 + tx 시트 D=category_parent 자동 생성
```

---

## 9. Recommended Next Step

**`/pdca report budget-tracker-m3` 진행 권장.**

### 근거

- Static Match Rate **96%** (≥ 90% threshold)
- 21/21 FRs 구현 (FR-46 partial — Plan §11.3 deferred 명시)
- **18/18 Decision Compliance** (100%)
- 0 Critical issues; 2 Important은 모두 명시적 deferred 또는 작은 UX 갭
- 16건 신규 테스트로 핵심 위험 경로 커버 (Sheets layout / hierarchy logic / daily aggregation / rollup correctness)

### Report 진행 전

1. `flutter analyze` (0 issues 기대)
2. `flutter test` (~92 통과 기대)
3. APK 빌드 + 디바이스 마이그레이션 검증

### M4 backlog 후보

- FR-46 dedicated migration test (drift `migration_runner`)
- 카테고리 자식 drag-reorder UI (~30 LOC)
- Tx 시트 헤더 강제 갱신 (기존 사용자 9→10 cols 자동 확장)
- Open Q1-Q5 (Plan §12)
- 카테고리 hierarchy + 반복 거래 + 예산 (Plan §3.2)

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-04-29 | Initial M3 analysis. Static Match 96% (Struct 100 / Func 95 / Contract 98). 0 Critical / 2 Important / 1 Minor. 18/18 decisions kept. Recommend report. |
