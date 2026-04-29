---
template: plan
version: 1.0
feature: budget-tracker-m3
cycle: M3
date: 2026-04-29
author: kyk@hunik.kr
project: personal-workspace
projectVersion: "0.4.0"
level: Dynamic
basePlan: docs/01-plan/features/budget-tracker-m2.plan.md
baseReport: docs/04-report/budget-tracker-m2.report.md
---

# Personal Budget Tracker — M3 Cycle Planning

> **Summary**: M2의 분석 차트 위에 **일별 시야**(달력 + heatmap)를 더하고, **반복 입력 부담**을 템플릿으로 제거. 가계부의 매일 사용성을 한 단계 끌어올림.
>
> **Cycle**: M3 (M2 완료 후속)
> **Status**: Draft
> **Method**: Plan (도메인 모델은 M1·M2에서 확정, 구조 보완)

---

## Executive Summary

| Perspective | Content |
|-------------|---------|
| **Problem** | M2까지의 분석은 카테고리·고정/변동 비중 위주. 일자별 시야 부재로 "어제 얼마 썼지?" 같은 즉각 질문에 ListScreen 스크롤이 필요. 매월 반복되는 고정비(월세/통신/구독) 입력 마찰. 그리고 카테고리가 평면 17개라 "식비" 같은 큰 묶음 안의 세부 항목(점심값/외식/카페)을 구분하지 못해 분석 해상도가 낮음. |
| **Solution** | **(A) 일별 소비 달력** — 분석 탭에 월 그리드 + heatmap, 탭 → 그 날짜 거래 내역. **(B) 거래 템플릿** — 자주 쓰는 거래 껍데기 저장 + InputScreen picker. Sheets `templates` 시트 동기화. **(C) 카테고리 2-level 계층** — `parent_category_id` 추가, "식비 > 점심값" 식으로 대분류/소분류 구조. 분석 도너츠는 대분류 집계, 입력은 cascading picker. |
| **Function/UX Effect** | 분석 탭 = 달력+도너츠+라인 3-층. InputScreen 상단 "📋 템플릿에서" + 카테고리는 cascading 2-step picker. 설정에 "거래 템플릿 관리" + "카테고리 관리" 두 sub-screen 신규. |
| **Core Value** | M2 = 이해 + 예측 → **M3 = 패턴 + 효율 + 해상도**. 일자별 회고 + 반복 입력 영구 제거 + 카테고리 세부 분석 = 가계부가 진짜 "매일 켜져있는" 도구가 됨. |

---

## Context Anchor

| Key | Value |
|-----|-------|
| **WHY** | 일자별 시야 + 반복 입력 부담 제거 + 카테고리 해상도 향상 → 매일 사용성 + 분석 깊이 강화 |
| **WHO** | 본인 1인 (M1·M2 사용자, 1-2개월 데이터 누적된 상태) |
| **RISK** | (1) Drift v3→v4 — 두 변경 동시 (templates 테이블 + categories.parent_category_id 컬럼) (2) Sheets templates 시트 신규 + transactions 시트 컬럼 9→10 (3) 템플릿 amount NULL 처리 (4) 달력 month picker state 공유 (5) 카테고리 cascading picker UX 복잡도 |
| **SUCCESS** | 달력 일별 합계 정확 / 템플릿 영구 재사용 / 카테고리 hierarchy로 도너츠 대분류 집계 + 입력 cascading 동작 / Sheets 동기화 / M2 데이터 0 손실 |
| **SCOPE** | 일별 달력 + 템플릿 CRUD/사용/sync + 카테고리 2-level + 마이그레이션 v4. 반복 자동, 예산은 M4. |

---

## 1. User Intent Discovery

### 1.1 Core Problem (M2 사용 후 발견)

**Problem 1 — 일자별 시야 부재**:
- M2 분석 탭은 카테고리 도너츠와 6개월 추이 라인은 보여주지만 "어제 얼마 썼지?" "지난 주 화요일 외식비?" 같은 일자별 즉답 불가
- 결국 내역 탭 스크롤로 추산. 시간 소모 큼
- 카드 결제일 D-day는 카드 상세에 있지만 이건 예측. **회고**(어제·지난주)를 위한 일자별 시야 없음

**Problem 2 — 반복 입력 부담**:
- 고정비(월세/관리비, 통신비, 구독료, 보험료, 대출이자) 매월 5건 × type/계좌/카테고리/메모 풀 입력
- 매월 ~3분 입력 마찰 → 입력 미루기 → 데이터 누락 → 분석 신뢰성 ↓
- M2 분석에서 "고정비 변동 적음" 패턴 확인됨 → 템플릿화하기 좋음

→ **M2가 만든 이해를 매일 회고하고, 입력 마찰을 없애 데이터 흐름을 끊김 없게**

### 1.2 Target Users

| User Type | Usage Context | Key Need |
|-----------|---------------|----------|
| 본인 (M1·M2 사용자, 1-2개월 데이터 누적) | 매일 1-2회 어제·오늘 회고 + 매월 1회 고정비 일괄 입력 | 일별 합계 즉시 확인 + 고정비 5초 입력 |

### 1.3 Success Criteria

- [ ] **일별 합계 정확**: 달력 셀의 expense 합계 = 그 날짜의 expense 거래 amount sum (단위 테스트로 검증)
- [ ] **달력 → 내역 이동**: 셀 탭 → 분석 탭 자동으로 내역 탭 전환 + 날짜 단일 일자 필터 적용
- [ ] **템플릿 prefill 정확**: 템플릿 선택 시 type/계좌/카테고리/메모/amount(NULL이면 빈칸) 정확히 폼에 채워짐
- [ ] **lastUsedAt 갱신**: 템플릿 사용 시 lastUsedAt 자동 갱신 → 다음 picker에서 위로 정렬
- [ ] **Sheets 동기화**: templates 시트에 snapshot overwrite. 디바이스 A에서 만든 템플릿이 B에서 보임
- [ ] **마이그레이션 무손실**: M2 디바이스 DB(v3)에서 v4로 자동 마이그레이션 + 거래/계좌 0 손실

### 1.4 Constraints

| Constraint | Details | Impact |
|------------|---------|--------|
| M1·M2 도메인 모델 유지 | 4-type Tx + Accounts + 4-시트 동기화 그대로 | High |
| 4탭 + FAB 구조 유지 | M2 reference 톤 (홈/내역/분석/계좌 + 중앙 FAB). 5탭으로 안 늘림 | High |
| Schema 마이그레이션 v3→v4 | tx_templates 테이블 추가 (addTable 패턴) | High |
| Sheets 시트 추가 | templates 신규 시트. ensureSheet 멱등 갱신 | Medium |
| Pretendard/SUIT 톤 유지 | M2에서 정착한 hot pink + cyan + 둥근 카드 | High (자동 반영) |
| APK ≤ 32MB | M2의 ~30MB에 약간 추가. 신규 의존성 X (table_calendar 안 씀, 자체 위젯) | Low |

---

## 2. Alternatives Briefly Considered

### 2.1 달력 위치

| 옵션 | 장단점 | 결정 |
|------|--------|------|
| **분석 탭 통합 (선택)** | 월 picker 공유, 4탭 유지, reference 톤 | ✅ |
| 새 탭 (5탭) | 우선순위 높을 때 | ❌ — NavigationBar 좁아짐 |
| 홈을 달력 중심으로 변경 | reference 첫 mockup 톤 | ❌ — 홈 hero/cards 손실 큼 |

### 2.2 달력 셀 표시

| 옵션 | 결정 |
|------|------|
| **합계 텍스트 + 색 농도(heatmap) (선택)** | ✅ 정량 + 직관 둘 다 |
| 합계만 | ❌ 시각 강도 약함 |
| 색 농도만 | ❌ 정확한 금액 모름 |

### 2.3 달력 expense 정의

| 옵션 | 결정 |
|------|------|
| **expense type만 (선택)** | ✅ M2 분석 차트와 일관. 카드 결제는 사용 시점에 expense로 잡힘 |
| expense + transfer-to-card | ❌ 카드 결제일에 큰 수치 → 그날 쓴 돈 같지 않음 |
| 수입 제외 전체 | ❌ valuation까지 들어가면 의미 모호 |

### 2.4 템플릿 관리 위치

| 옵션 | 장단점 | 결정 |
|------|--------|------|
| **설정 sub-screen (선택)** | 4탭 유지, 사용 진입은 InputScreen picker로 충분 | ✅ |
| 새 탭 (5탭) | 가시성 ↑ | ❌ — 사용 빈도 대비 과함 |
| 계좌 탭 안 | 의미 안 맞음 | ❌ |

### 2.5 템플릿 amount

| 옵션 | 결정 |
|------|------|
| **nullable 허용 (선택)** | ✅ 고정비도 실제 약간 변동 (전기/통신). NULL = 사용자가 입력 시점에 입력 |
| amount 필수 | ❌ 매번 prefill 후 수정 = nullable과 별 차이 없음. 유연성 손실 |

### 2.6 템플릿 정렬

| 옵션 | 결정 |
|------|------|
| **sortOrder + lastUsedAt (선택)** | ✅ 수동 컨트롤 + "최근 자주 쓴" 자동 우선 노출 |
| sortOrder만 | ❌ 자동 우선순위 없음 |
| usageCount + sortOrder | ❌ 장기 평균보다 최근성이 더 유용 |

---

## 3. YAGNI Review

### 3.1 Included (M3 Must-Have)

**Feature A — 일별 달력**
- [ ] 달력 위젯 (월 그리드 + heatmap + 합계)
- [ ] AnalyticsRepository.dailyExpenseMap(month) 메서드
- [ ] 달력 셀 탭 → 분석 탭에서 내역 탭으로 자동 전환 + 날짜 단일 일자 필터 적용

**Feature B — 거래 템플릿**
- [ ] tx_templates 테이블 + TemplatesDao + TemplateRepository
- [ ] 설정 → "거래 템플릿 관리" sub-screen (CRUD + sortOrder reorder)
- [ ] TemplateFormSheet (생성/수정 BottomSheet)
- [ ] InputScreen 상단 "📋 템플릿에서" 버튼 + BottomSheet picker
- [ ] 템플릿 사용 시 폼 prefill + lastUsedAt 갱신
- [ ] Sheets templates 시트 추가 (snapshot overwrite)

**Feature C — 카테고리 2-level 계층**
- [ ] categories.parent_category_id 컬럼 추가 (self-FK NULLABLE)
- [ ] 기존 17개 시드는 모두 대분류(parent NULL) 유지 — 사용자가 관리 화면에서 소분류 추가
- [ ] CategoryRepository 메서드 추가 (listTopLevel, listChildren, setParent, reorder)
- [ ] CategoryPicker 위젯 (cascading 대분류 → 소분류, InputScreen·TemplateFormSheet·FilterChip 공유)
- [ ] 설정 → "카테고리 관리" sub-screen (CRUD + parent 지정 + drag-reorder)
- [ ] 분석 도너츠 — 대분류 기준 집계 (소분류는 같은 부모로 합쳐짐)
- [ ] Sheets transactions 시트 — `category_parent` + `category` 2 컬럼 분리 (9→10 컬럼, A:I → A:J)

**공통**
- [ ] 마이그레이션 v3→v4 (tx_templates 신규 테이블 + categories.parent_category_id 컬럼 동시 적용)
- [ ] sheet_layout_test 보강 (templates 헤더 + tx 10 컬럼 검증)
- [ ] TemplateRepository 통합 테스트 + dailyExpenseMap 단위 테스트 + Category hierarchy 통합 테스트

### 3.2 Deferred (M4)

| Feature | Reason | Revisit |
|---------|--------|---------|
| 반복 거래 자동 생성 | 템플릿 + 스케줄 = 큰 작업. 템플릿 먼저 정착 후 결정 | M4 |
| 예산 설정 + 초과 경고 | 카테고리 분석 + 일별 시야 누적된 후 의미 | M4 |
| 양방향 sheet sync (디바이스 → 시트 + 시트 → 디바이스 pull) | M3 템플릿 사용 후 진짜 필요한지 평가 | M4 |
| 월별·연도별 리포트 | 도너츠/라인/달력으로 충분한지 사용 후 평가 | M4 또는 보류 |
| 종목별 시세 자동 갱신 | 보류 — 수동 valuation으로 충분 | M5+ |
| 다국어 지원 | 본인 1인은 한국어만 | 보류 |

### 3.3 Removed (Won't Do)

| Feature | Reason |
|---------|--------|
| `table_calendar` 패키지 도입 | APK 증가 + heatmap 커스터마이즈 어려움. 자체 GridView 위젯이 더 가볍고 reference 톤 맞춤 |
| 달력 셀 다중 라인(income/expense 둘 다) | 시각 복잡. expense만 표시 |
| 템플릿 카테고리 그룹핑 | 템플릿 5-10개 수준 가정. flat 리스트로 충분 |
| 템플릿 → InputScreen 자동 저장 (1-tap quick add) | 금액 변동 가능성 + UX 명확성 떨어짐. 명시적 입력 단계 유지 |

---

## 4. Scope

### 4.1 In Scope (M3)

- 일별 달력 위젯 + dailyExpenseMap + 분석 탭 통합 + 셀 탭 → 내역 전환
- tx_templates 테이블 + 마이그레이션 v4 + DAO + Repository
- 거래 템플릿 관리 (설정 sub) + TemplateFormSheet + InputScreen picker + lastUsedAt
- Sheets templates 시트 + SyncService 통합
- categories.parent_category_id 컬럼 + CategoryRepository hierarchy 메서드
- CategoryPicker 위젯 (cascading) — InputScreen·TemplateFormSheet·FilterChip 공유
- 카테고리 관리 (설정 sub) — CRUD + parent 지정 + drag-reorder
- 분석 도너츠 대분류 집계
- Sheets transactions 시트 category 2-컬럼 분리 (9→10 cols)
- sheet_layout_test 보강 + 통합 테스트 (TemplateRepository + Category hierarchy + dailyExpenseMap)

### 4.2 Out of Scope (M3)

- 반복 자동 생성, 예산, 월별 리포트, 시세 자동 (M4+)
- 템플릿 amount의 통계적 보정 (히스토리 기반 평균 제안 등) — M5
- 달력 멀티-월 표시 (단일 월 뷰만)
- 카테고리 3-level+ 깊은 hierarchy — 2-level만
- 카테고리 색상 커스터마이즈 (도너츠 자동 색상 회전 유지)

---

## 5. Requirements

### 5.1 Functional Requirements (M3 신규)

| ID | Requirement | Priority | Status |
|----|-------------|:--------:|:------:|
| FR-33 | tx_templates 테이블 추가 (id, name, type, amount NULLABLE, fromAccountId, toAccountId, categoryId, memo, sortOrder, lastUsedAt, createdAt, updatedAt) + Drift 마이그레이션 v3→v4 | High | Pending |
| FR-34 | TxTemplate 도메인 객체 + TemplatesDao (CRUD + watchAll sortOrder/lastUsedAt) + TemplateRepository | High | Pending |
| FR-35 | 설정 → "거래 템플릿 관리" sub-screen (목록/생성/수정/삭제, drag-reorder로 sortOrder 변경) | High | Pending |
| FR-36 | TemplateFormSheet (BottomSheet, 생성/수정. amount nullable. type별 필드 분기는 InputScreen 패턴 재사용) | High | Pending |
| FR-37 | InputScreen 상단 "📋 템플릿에서" 버튼 + BottomSheet picker (lastUsedAt desc 정렬) | High | Pending |
| FR-38 | 템플릿 선택 시 form prefill + occurredAt = 오늘 + lastUsedAt 자동 갱신 (저장 성공 시점) | High | Pending |
| FR-39 | AnalyticsRepository.dailyExpenseMap(DateTime month) → Map<DateTime, int> (expense 합계 by 날짜) | High | Pending |
| FR-40 | DailyCalendar 위젯 (월 그리드 + 일별 합계 텍스트 + heatmap 색 농도 = 그달 max 대비 alpha) | High | Pending |
| FR-41 | AnalyticsScreen에 달력 통합 (월 picker 공유. 위→아래: 달력 → 도너츠 → 라인) | High | Pending |
| FR-42 | 달력 셀 탭 → searchFilter에 단일 일자 DateRange 적용 + StatefulShellRoute로 내역 탭(인덱스 1) 전환 | High | Pending |
| FR-43 | Sheets templates 시트 추가. headers = name/type/amount/from_account/to_account/category/memo/sort_order/last_used_at (9컬럼). overwriteRange A1:I | High | Pending |
| FR-44 | SyncService._pushTemplatesSnapshot 추가. ensureSheet으로 헤더 멱등 갱신. 기존 사용자는 첫 동기화 시 자동 시트 생성 | High | Pending |
| FR-45 | sheet_layout_test 보강 — templates 9컬럼 + tx 10컬럼 + A1:G(accounts)/A1:I(templates)/A:J(tx) 검증 | Medium | Pending |
| FR-46 | 마이그레이션 v3→v4 in-memory 테스트 (v3 schema → v4 → tx_templates 테이블 존재 + categories.parent_category_id 컬럼 존재 + 기존 데이터 보존) | Medium | Pending |
| FR-47 | categories 테이블에 `parent_category_id INTEGER NULLABLE FK` 컬럼 추가. 기존 17개 시드는 parent NULL (모두 대분류) 유지 | High | Pending |
| FR-48 | CategoryRepository 메서드 추가 — listTopLevel(kind), listChildren(parentId), setParent(id, parentId), reorder(ids), 그리고 isResolvableWith helper | High | Pending |
| FR-49 | CategoryPicker 위젯 (cascading 2-step BottomSheet 또는 Wrap chip 2-row). InputScreen·TemplateFormSheet·FilterChip 카테고리 chip이 공유 | High | Pending |
| FR-50 | 설정 → "카테고리 관리" sub-screen — 대분류 list + 각 대분류 expand로 소분류 표시. CRUD + parent 지정 + drag-reorder. /settings/categories push route | High | Pending |
| FR-51 | 분석 도너츠 — `AnalyticsRepository.categoryDonut`이 leaf 카테고리를 부모로 rollup 집계 (parent_category_id 따라 합산). 도너츠 라벨은 대분류 이름 | High | Pending |
| FR-52 | Sheets transactions 시트 category 분리 — `category_parent` (D) + `category` (E) 2 컬럼. 9컬럼 → 10컬럼, range A:I → A:J. SyncService._txToRow에 parentName 매핑 | High | Pending |
| FR-53 | Category hierarchy 통합 테스트 4건 — listTopLevel/listChildren/setParent/categoryDonut rollup 집계 정확 | Medium | Pending |

### 5.2 Non-Functional Requirements

| Category | Criteria | Measurement |
|----------|----------|-------------|
| 성능 (달력 진입) | 분석 탭 진입 ≤ 400ms (10K 거래) | dailyExpenseMap 인덱스 활용 + 결과 30 entries 이하 |
| 성능 (템플릿 picker 표시) | BottomSheet 열기 ≤ 100ms (50개 템플릿 가정) | watchAll Stream + 메모리 정렬 |
| APK 크기 | ≤ 32MB | M2 ~30MB + 신규 의존성 0 |
| 데이터 무결성 | M2→M3 마이그레이션 후 거래/계좌/카테고리 모두 보존 | in-memory 테스트 + 디바이스 실증 |
| 템플릿 amount NULL UX | InputScreen prefill 시 amount 필드가 visually empty (hint "0"만) | 수동 검증 |

---

## 6. Success Criteria (Definition of Done)

### 6.1 M3 DoD

- [ ] FR-33~FR-53 구현 (전체 또는 명시적 deferred 표시)
- [ ] flutter analyze 0 issues
- [ ] flutter test 모두 통과 (M1 63 + M2 ~13 + M3 신규 ~14 = ~90)
- [ ] **TemplateRepository 통합 테스트 4건** + **Category hierarchy 통합 테스트 4건** 통과
- [ ] **dailyExpenseMap 단위 테스트 통과** (빈 달, 단일 날짜, 월 경계, expense 외 type 제외)
- [ ] **categoryDonut rollup 집계 단위 테스트** (소분류 → 부모로 합산 정확)
- [ ] Drift v3→v4 마이그레이션 작성 (templates 테이블 + parent_category_id 컬럼 동시) + 디바이스 검증 (기존 M2 데이터 보존)
- [ ] APK 빌드 + 본인 핸드폰 설치 + 달력 + 템플릿 + 카테고리 hierarchy 모두 동작 검증

### 6.2 Quality Criteria

- [ ] flutter analyze 0 warnings
- [ ] Repo/Sync 통합 테스트 커버리지 유지 (≥ 60%, M2 baseline 이상)
- [ ] 마이그레이션 전후 잔액 무결성 검증 통과 (BalanceReconciler)
- [ ] Sheets templates 시트 양방향 검증 (디바이스 A → 시트 → 디바이스 B 시나리오)

---

## 7. Risks and Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Drift v3→v4 마이그레이션 데이터 손실 | High | Low | `addTable`만 사용 (idempotent). v3→v4 in-memory 테스트로 마이그레이션 실행 + 기존 데이터 검증. M2의 v2→v3 패턴 그대로 |
| 템플릿 amount NULL → 잘못 0으로 저장 | Medium | Medium | InputForm에 "amount > 0 검증"을 NewTransaction.validate()에서 이미 강제. NULL 템플릿은 사용자가 입력하기 전엔 저장 시도해도 차단됨 (안전) |
| Sheets `templates` 시트 기존 사용자 호환 | Medium | Low | `ensureSheet`이 시트 없으면 자동 생성. 첫 sync에서 시트+헤더 만들어짐. 기존 3 시트(transactions/accounts/monthly_summary)는 영향 없음 |
| 달력 month picker 공유로 인한 state lift up | Medium | Medium | AnalyticsScreen이 이미 `_selectedMonth` state 보유. 달력에 같은 state 전달만 하면 됨 (down). 도너츠는 family로 캐싱 유지 |
| 달력 셀 탭 시 내역 탭 자동 전환 | Medium | Medium | StatefulShellBranch.goBranch(1) + searchFilterProvider.setDateRange. 두 동작 동시. 단순한 로직이지만 testing이 까다로움 |
| 템플릿 "사용" 시 lastUsedAt 갱신 타이밍 | Low | Medium | 저장 성공 시점에 갱신 (취소면 갱신 안 함). Repository 안에서 transaction insert 직후 update |
| 템플릿 categoryId/accountId가 삭제된 계좌·카테고리 가리킴 | Medium | Medium | UI에서 "유효하지 않은 템플릿" 표시. Repository에서 사용 시점에 ID 유효성 체크. NULL이면 폼에 빈값 prefill |
| categories.parent_category_id 자기참조 — 순환 (A→B→A) | Low | Low | UI에서 parent 지정 시 children 트리 검사로 순환 방지. 또는 단순 2-level 강제(부모는 NULL이어야 함, child는 부모 NULL인 카테고리만 가리킬 수 있음) |
| Sheets transactions 시트 컬럼 9→10 변경 — 기존 사용자 시트 호환 | Medium | Medium | 시트는 append-only이므로 기존 행은 9 cols 그대로, 새 행은 10 cols. ensureSheet은 매번 헤더 행 overwrite하지 않음 → 기존 사용자 시트 헤더는 9 cols 유지. **수동**: 사용자에게 첫 sync 후 시트 헤더에 D 옆 새 컬럼 직접 추가 안내, 또는 시트 헤더만 강제 갱신 로직 추가 |
| 카테고리 cascading picker UX 복잡도 | Medium | Low | 2-step만 (대분류 → 소분류). 소분류 없는 대분류는 "(소분류 없음)" 옵션 = 대분류 자체 사용. AccountFormSheet의 type-conditional 패턴과 비슷한 구조 |
| 분석 도너츠 rollup 정확성 | Medium | Low | leaf의 parent를 따라 합산. parent가 NULL인 leaf는 자신이 대분류. 통합 테스트로 검증 |

---

## 8. Architecture Considerations

### 8.1 변경 없는 부분

| 영역 | M2 결정 유지 |
|------|------------|
| 회계 모델 | 4-type Tx + Accounts (변경 없음) |
| 잔액 갱신 | atomic via AccountsDao (변경 없음) |
| 동기화 패턴 | 3 시트 (transactions/accounts/monthly_summary) + 신규 1 (templates) = 4 시트 |
| 상태관리 | Riverpod 2.x |
| 라우팅 | GoRouter — 4 branch 유지. 설정 push route에 sub-route 추가 |
| 로컬 DB | Drift v3 → v4 (addTable) |
| 테마 | M2 정착 (hot pink + cyan + SUIT) |

### 8.2 신규 모듈/파일

```
lib/
├── features/
│   ├── analytics/
│   │   ├── data/
│   │   │   └── analytics_repository.dart          # ✏️ +dailyExpenseMap() + categoryDonut rollup
│   │   └── ui/
│   │       ├── analytics_screen.dart              # ✏️ +DailyCalendar
│   │       └── daily_calendar.dart                # 🆕 (월 그리드 + heatmap)
│   ├── templates/                                 # 🆕 신규 모듈
│   │   ├── domain/
│   │   │   └── tx_template.dart                   # 🆕 (값 객체)
│   │   ├── data/
│   │   │   ├── templates_dao.dart                 # 🆕
│   │   │   └── template_repository.dart           # 🆕
│   │   └── ui/
│   │       ├── templates_screen.dart              # 🆕 (설정 sub: 목록/관리)
│   │       ├── template_form_sheet.dart           # 🆕 (생성/수정 BottomSheet)
│   │       └── template_picker_sheet.dart         # 🆕 (Input에서 호출)
│   ├── categories/
│   │   ├── data/
│   │   │   └── category_repository.dart           # ✏️ +listTopLevel/listChildren/setParent/reorder
│   │   ├── domain/
│   │   │   └── category.dart                      # ✏️ +parent helper extension
│   │   └── ui/                                    # 🆕 신규 sub
│   │       ├── categories_screen.dart             # 🆕 (설정 sub: 대분류+소분류 list, CRUD, parent 지정, drag-reorder)
│   │       ├── category_form_sheet.dart           # 🆕 (생성/수정 BottomSheet, parent dropdown 포함)
│   │       └── category_picker.dart               # 🆕 (cascading 2-step picker — Input·TemplateForm·FilterChip 공유)
│   ├── transactions/ui/
│   │   ├── input_screen.dart                      # ✏️ "📋 템플릿에서" 버튼 + CategoryPicker swap
│   │   └── filter_chips.dart                      # ✏️ 카테고리 chip → CategoryPicker 사용
│   └── settings/ui/
│       └── settings_screen.dart                   # ✏️ "거래 템플릿 관리" + "카테고리 관리" entries
└── core/db/
    ├── tables.dart                                # ✏️ +TxTemplates 테이블 +Categories.parentCategoryId
    ├── app_database.dart                          # ✏️ schemaVersion=4
    └── migrations/
        └── v3_to_v4.dart                          # 🆕 createTable(txTemplates) + addColumn(categories.parentCategoryId)
```

```
lib/infrastructure/sheets/
└── sheet_layout.dart                              # ✏️ +templatesSheet/Header +txHeader 10 cols (+category_parent)

lib/features/sync/service/
└── sync_service.dart                              # ✏️ +_pushTemplatesSnapshot, _txToRow에 parentName 추가

lib/app/
├── providers.dart                                 # ✏️ +templates/categories providers
└── router.dart                                    # ✏️ /settings/templates + /settings/categories push routes
```

### 8.3 핵심 데이터 흐름 (달력 진입)

```
User opens 분석 탭
  → AnalyticsScreen
  → ref.watch(dailyExpenseMapProvider(_selectedMonth))
       AnalyticsRepository.dailyExpenseMap(month)
         SELECT occurred_at::date, SUM(amount) FROM transactions
         WHERE type='expense' AND occurred_at IN [month range]
           AND deleted_at IS NULL
         GROUP BY date
       → Map<DateTime, int>
  → DailyCalendar 렌더 (그리드 + heatmap)
  → User taps 04-15 cell
  → goBranch(1) (내역 탭) + searchFilterProvider.setDateRange(04-15 single day)
  → ListScreen에서 그 날짜 거래 필터링됨
```

### 8.4 핵심 데이터 흐름 (템플릿 사용)

```
User taps FAB → InputScreen
  → 상단 "📋 템플릿에서" 버튼 탭
  → showModalBottomSheet → TemplatePickerSheet
       ref.watch(templatesListProvider) (lastUsedAt desc)
  → 사용자 템플릿 선택
  → InputFormNotifier.applyTemplate(template):
       setType, setAmount(if not null), setFrom, setTo, setCategory, setMemo
       (occurredAt은 변경 안 함 — 이미 오늘로 초기화됨)
  → BottomSheet 닫힘, 폼 채워짐
  → 사용자가 amount 등 수정 후 [저장]
  → repo.add(draft) 성공 후
  → templateRepository.markUsed(template.id) → lastUsedAt = now
```

### 8.5 Drift 마이그레이션 v3 → v4

```dart
// core/db/migrations/v3_to_v4.dart
class V3ToV4 {
  static Future<void> apply(Migrator m, AppDatabase db) async {
    await m.createTable(db.txTemplates);
    await m.addColumn(db.categories, db.categories.parentCategoryId);
  }
}

// app_database.dart
@override
int get schemaVersion => 4;

@override
MigrationStrategy get migration => MigrationStrategy(
  onCreate: (m) => m.createAll(),
  onUpgrade: (m, from, to) async {
    if (from < 3) await V2ToV3.apply(m, this);
    if (from < 4) await V3ToV4.apply(m, this);
  },
  beforeOpen: ...
);
```

### 8.6 Sheets templates 시트

```
columns: name | type | amount | from_account | to_account | category | memo | sort_order | last_used_at
range:   templates!A1:I
sync:    overwrite snapshot (accounts/monthly_summary와 동일 패턴)
```

기존 사용자 시트는 첫 동기화 시 `ensureSheet('templates', headers)`가 자동 생성.

### 8.7 Sheets transactions 시트 카테고리 분리

```
Before (M2): date | type | amount | category | from_account | to_account | memo | tx_id | synced_at  (9 cols, A:I)
After (M3):  date | type | amount | category_parent | category | from_account | to_account | memo | tx_id | synced_at  (10 cols, A:J)
```

- D 위치에 `category_parent` 신규 컬럼 (대분류 이름)
- E는 기존 `category` (leaf 이름; 부모 없으면 동일 카테고리 이름)
- 컬럼 인덱스 변경: `txIdColIdx` 7 → 8, `txAppendRange` A:I → A:J, `txIdSearchRange` H:H → I:I
- **기존 사용자 호환**: 시트는 append-only이므로 기존 행 9 cols 유지. 첫 sync 시 시트 헤더는 자동 갱신 안 됨. **수동**: 사용자가 헤더 행에 `category_parent` 컬럼 직접 추가하거나, 신규 sync 코드가 헤더 mismatch 감지 시 강제 갱신 (M3.4 결정 필요).

### 8.8 categories 테이블 마이그레이션

```dart
// tables.dart 변경 부분
class Categories extends Table {
  // ... 기존 컬럼들 (id, name, kind, isFixed, sortOrder)
  IntColumn get parentCategoryId => integer()
      .nullable()
      .customConstraint('NULL REFERENCES categories(id) ON DELETE SET NULL')();
}
```

ON DELETE SET NULL로 대분류 삭제 시 자식의 parent를 NULL로 (자식이 대분류로 승격).

---

## 9. Convention Prerequisites

M2와 동일 (Flutter lints + Riverpod naming + Drift naming + 한국어 UI). 추가:

- 마이그레이션 스크립트는 `core/db/migrations/v{from}_to_{to}.dart` 명명 (M2 표준 유지)
- 새 features 모듈은 `domain/` `data/` `ui/` 3 폴더 구조 (기존 패턴)

---

## 10. Milestones

> 카테고리 hierarchy 추가로 4 → 5 sessions로 확장. 총 ~13일 (기존 9일 + 4일).

| MS | 범위 | 핵심 작업 | 예상 |
|----|------|-----------|------|
| **M3.1 schema** | tx_templates 테이블 + categories.parent_category_id 컬럼 + v3→v4 마이그레이션 + TemplatesDao/Repository + CategoryRepository hierarchy 메서드 | 1건 마이그레이션에 2개 변경 동시 적용. 통합 테스트 베이스 | 2일 |
| **M3.2 template-mgmt** | 설정 sub-screen + TemplateFormSheet + drag-reorder + InputScreen picker + lastUsedAt 갱신 | TemplatesScreen + Form + Picker + Riverpod providers | 3일 |
| **M3.3 categories-ui** | CategoryPicker 위젯 (cascading) + CategoryManagementScreen + CategoryFormSheet + InputScreen·TemplateForm·FilterChip 카테고리 chip swap + 분석 도너츠 rollup | 카테고리 hierarchy UI + 모든 진입점 통일 | 3일 |
| **M3.4 calendar** | dailyExpenseMap + DailyCalendar 위젯 + AnalyticsScreen 통합 + 셀 탭 → 내역 전환 | DAO + 위젯 + heatmap + state 공유 | 2일 |
| **M3.5 sheets-tests** | Sheets templates 시트 + tx 10컬럼 분리 + SyncService 통합 + sheet_layout_test 보강 + 통합 테스트 + APK 검증 | sheet schema 변경 + 회귀 테스트 + 디바이스 실증 | 2일 |

총 ~12일 (M2 사이클 ~10일보다 약간 큼).

---

## 11. Next Steps

1. [ ] Plan 검토 후 → `/pdca design budget-tracker-m3` (Design 문서 + 3 옵션 + Module Map)
2. [ ] M3.1부터 순서대로 구현 (`/pdca do budget-tracker-m3 --scope schema-template`)
3. [ ] 각 세션마다 build_runner + flutter analyze + flutter test 실행 후 다음 세션
4. [ ] M3 사이클 종료 → `/pdca analyze` → `/pdca report` → `/pdca archive --summary`

---

## Version History

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-04-29 | Initial M3 plan — 일별 달력 + 거래 템플릿. 4 결정 잠금. 마이그레이션 v3→v4 (templates 테이블만). 4 sessions ~9일. | kyk@hunik.kr |
| 1.1 | 2026-04-29 | **카테고리 2-level 계층 (Feature C) 추가**. categories.parent_category_id 컬럼 + CategoryPicker 위젯 + CategoryManagementScreen + 분석 도너츠 rollup + Sheets tx 카테고리 2-컬럼 분리. 5 sessions ~12일. FR-47~53 추가. 시드는 기존 17개 = 대분류만 유지, 사용자가 소분류 추가. | kyk@hunik.kr |
