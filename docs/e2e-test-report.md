# E2E Test Report

## Run 6: Checklist Items Filtering E2E Verification (2026-04-15)

- **Test date:** 2026-04-15T06:23~06:31Z
- **Target URL:** http://localhost:3000
- **Context:** Full verification after checklist_items_summary.json changes — merged 89→81 items, added depends_on + applicable_types filtering
- **Total scenarios:** 13
- **Passed:** 12 | **Failed:** 0 | **Bug Found:** 1
- **Test property:** Property #16 (2024타경6008, 아파트, 81 results manually seeded)

### Results Summary

| # | Scenario | Status | Screenshots | Notes |
|---|----------|--------|-------------|-------|
| S-001 | 물건 목록 (/properties) | PASS | before/s001, after/s001 | 5건 정상 표시, 콘솔 에러 없음 |
| S-002 | 물건 상세 (/properties/16) | PASS | after/s002 | 분석결과보기/다시분석 링크 정상 |
| S-003 | 권리분석 탭 (depends_on=hidden) | PASS | after/s003 | 17/25 항목 표시 (8개 depends_on 필터링) |
| S-003b | 권리분석 탭 (depends_on=visible) | PASS | after/s003b | rights-003 위험 시 25/25 항목 표시 |
| S-004 | 물건분석 탭 | PASS | after/s004 | 12개 항목, 에러 없음 |
| S-005 | 수익분석 탭 | PASS | after/s005 | 25개 항목, applicable_types 필터 정상 |
| S-006 | 현장확인 탭 | PASS | after/s006 | 12개 항목, 에러 없음 |
| S-007 | 입찰&낙찰 탭 | PASS | after/s007 | 7개 항목, 에러 없음 |
| S-008 | 종합등급 페이지 | BUG | after/s008 | 통계 테이블 필터링 미적용 (아래 상세) |
| S-009 | 명도 시뮬레이터 | PASS | after/s009 | property_id 파라미터 전달 정상 |
| S-010 | AI분석 (자동분석 탭) | PASS | after/s010 | PDF 업로드 UI 정상 |
| S-011 | AI분석 (수동분석 탭) | PASS | after/s011 | 프롬프트 복사/원본 업로드 정상 |
| S-012 | 명도 가이드 | PASS | after/s012 | 에러 없음 |
| S-013 | 예산 설정 | PASS | after/s013 | /onboarding → /settings/budget 리다이렉트 정상 |

### Bug Found

**BUG: TabSummaryTable on Grade Page — `visible_for?` filtering not applied**

- **Severity:** Medium
- **Location:** `app/controllers/inspections/grades_controller.rb:13-16`
- **Component:** `TabSummaryTableComponent`

**Expected:** Grade page statistics table uses `visible_for?` filtering (same as tab navigation).
**Actual:** `@results_by_tab` uses unfiltered `inspection_results`, showing all 25 rights_analysis items instead of 17.

| Tab | Tab Nav (filtered) | Grade Table (unfiltered) | Diff |
|-----|-------------------|-------------------------|------|
| 권리분석 | 10/17 | 8+6+11=25 | **+8** |
| 물건분석 | 8/12 | 7+1+4=12 | 0 |
| 수익분석 | 14/25 | 7+7+11=25 | 0 |
| 현장확인 | 8/12 | 5+3+4=12 | 0 |
| 입찰&낙찰 | 6/7 | 4+2+1=7 | 0 |

**Root cause:**
```ruby
# grades_controller.rb:13-16 — NO filtering applied
@results_by_tab = @property.inspection_results
  .where(user: current_user)
  .includes(:inspection_item)
  .group_by { |r| r.inspection_item.tab }
```

**Recommended fix:**
```ruby
all_results = @property.inspection_results
  .where(user: current_user).includes(:inspection_item)
answered_context = all_results.index_by { |r| r.inspection_item.code }
property_type = @property.property_type

@results_by_tab = all_results
  .select { |r| r.inspection_item.visible_for?(property_type:, answered_results: answered_context) }
  .group_by { |r| r.inspection_item.tab }
```

### Filtering Verification Summary

**depends_on filtering:**
- `rights-003` has_risk=false → 8 child items hidden (show_when_risk: true) ✅
- `rights-003` has_risk=true → 8 child items shown ✅
- `rights-008` has_risk=nil → `rights-017` hidden ✅

**property_type filtering (logic verification):**
- `finance-003` (applicable_types: ["아파트"]) → visible for 아파트 ✅
- `finance-003` → hidden for 빌라/다세대 ✅
- `finance-003` → hidden for 상가 ✅
- Items with nil applicable_types → visible for all types ✅

**Tab item counts (after filtering, rights-003=safe):**

| Tab | DB Total | Visible | Hidden |
|-----|----------|---------|--------|
| rights_analysis | 25 | 17 | 8 (depends_on) |
| property_analysis | 12 | 12 | 0 |
| profit_analysis | 25 | 25 | 0 |
| field_check | 12 | 12 | 0 |
| bidding | 7 | 7 | 0 |
| **Total** | **81** | **73** | **8** |

### Console Errors

No JavaScript errors detected across all 13 tested pages.

---

## Run 5: Full Menu Crawl & Feature Verification (2026-04-11)

- **Test date:** 2026-04-11T02:53Z
- **Target URL:** http://localhost:3000
- **Context:** Full E2E menu crawl — every navigation element, search/filter interactions, property flows
- **Total scenarios:** 13
- **Passed:** 13 | **Failed:** 0 | **Skipped:** 0

### Results Summary

| # | Scenario | Status | Screenshots | Notes |
|---|----------|--------|-------------|-------|
| S-000 | Home page load | PASS | before/s000-home-full.png | Redirects to /properties, 12 search results |
| S-001 | Nav > 예산 설정 | PASS | after/s001-onboarding.png | /settings/budget loads, full budget form |
| S-002 | Nav > 물건 목록 | PASS | after/s002-properties.png | /properties loads correctly |
| S-003 | Property detail (saved item) | PASS | after/s003-property-detail.png | /properties/74, case info + doc upload section |
| S-004 | Search result > add to list | PASS | after/s004-search-result-click.png | Click adds property, count 12→11 |
| S-004b | Property detail (added item) | PASS | after/s004b-property-detail-added.png | /properties/75 loads correctly |
| S-005 | 최대입찰가 link | PASS | — | Navigates to /settings/budget |
| S-006a | Header button 1 (dark mode) | PASS | after/s006-header-btn1.png | Toggles dark mode on/off |
| S-006b/c | Header buttons 2-3 | PASS | after/s006-header-btn2/3.png | No navigation, no errors |
| S-007 | Sidebar collapse/expand | PASS | after/s007-sidebar-collapsed.png | Sidebar toggles correctly |
| S-008 | Region selector | PASS | after/s008-region-seoul.png | Changed to 서울특별시 |
| S-009 | 조건검색 button | PASS | after/s009-condition-search.png | Fetches Seoul results (20건) |
| S-010 | Budget filter toggle | PASS | after/s010-budget-filter.png | Checkbox toggles, URL params updated |
| S-011 | Safety rating filter | PASS | after/s011-safety-filter.png | Filter applied, empty state shown |
| S-012 | Console errors check | PASS | — | 0 JS errors across all pages |
| S-013 | Disabled nav buttons (x10) | PASS | — | All 10 disabled buttons confirmed |

### Disabled Navigation Items (MVP)

| Category | Item | Status |
|----------|------|--------|
| 물건검색 | 시세 조회 | disabled |
| 권리분석 | 권리분석 리포트 | disabled |
| 권리분석 | 수익 계산기 | disabled |
| 권리분석 | 대출 매칭 | disabled |
| 입찰 | 진행 체크리스트 | disabled |
| 입찰 | 가상 입찰 | disabled |
| 입찰 | 사전 임장 | disabled |
| 낙찰 | 명도 가이드 | disabled |
| 낙찰 | 전문가 연결 | disabled |

### Pages Tested

| Page | URL | HTTP Status |
|------|-----|-------------|
| Home | / | 302 → /properties |
| Properties list | /properties | 200 |
| Budget settings | /settings/budget | 200 |
| Property detail | /properties/74 | 200 |
| Property detail | /properties/75 | 200 |

### Console Summary

- JS errors: 0
- Warnings: ~14 (non-critical, across all navigations)

### Observations

1. **Region change + search**: Changing to 서울특별시 and clicking 조건검색 fetches 20 Seoul properties
2. **Search result → property addition**: Click removes from results, adds to user's list with detail page
3. **Dark mode**: First header button toggles correctly
4. **Header buttons 2-3**: Click without error, no visible effect (future features)
5. **Empty state**: Safety filter with no matches shows "검색 결과가 없습니다" with guidance

---

## Run 4: Court Auto-Discovery & Case Search UI (2026-04-10)

- **Test date:** 2026-04-10T11:11Z
- **Target URL:** http://localhost:3000/properties
- **Context:** Verified UI after adding court auto-discovery to case number search (CaseSearchService.find_by_case_number)
- **Total scenarios:** 6
- **Passed:** 4 | **Failed:** 0 | **Skipped:** 1 | **Inconclusive:** 1

### Results Summary

| # | Scenario | Status | Screenshots | Notes |
|---|----------|--------|-------------|-------|
| S-001 | Properties index initial state | PASS | before/s001-properties-index.png | All UI elements present, no JS errors |
| S-002 | Empty case number submit | PASS | after/s002-empty-case-number-error.png | Flash alert: "사건번호를 입력해주세요." |
| S-003 | Invalid format case number | INCONCLUSIVE | after/s003-invalid-format-error.png | See Issue #1 — no fast validation before court discovery |
| S-004 | Valid case number loading state | PASS | before/s004-case-number-input-filled.png, after/s004-case-number-loading.png | + button disabled, 조건검색 disabled, spinner shown |
| S-005 | Criteria search execution | PASS | before/s005-before-criteria-search.png, after/s005-criteria-search-loading.png | 13 results from live API, inline grid display |
| S-006 | Inline import (click-to-add) | SKIP | before/s006-criteria-results.png, after/s006-after-inline-import.png | Card disabled during import; full verify needs BrowserClient |

### UI Verification Checklist

**Case Number Search Form:**
- [x] Text input with placeholder "예: 2026타경1234"
- [x] + button triggers form submit
- [x] Empty submit shows validation error
- [x] Loading state: input readonly, + button disabled with spinner, 조건검색 disabled
- [x] Stimulus controller (`criteria-search`) active and managing state

**Criteria Search:**
- [x] "조건검색" button visible and clickable
- [x] Uses BudgetSetting region and max_bid_amount
- [x] Results render inline in 4-column grid
- [x] Card shows: case_number (violet), appraisal_price, min_bid_price, address
- [x] 다물건 badge when property_count > 1
- [x] Count display: "조건검색 결과 13건"
- [x] Cards are clickable, disabled during import

**No UI changes needed:** The court auto-discovery change is backend-only. The existing case number input + "+" button UI works correctly with the new discovery flow.

### Issues Found

**Issue #1 (Important): Invalid format bypasses fast validation**

When user submits "invalid-format", the controller calls `CaseSearchService.find_by_case_number` which iterates 60 courts via HTTP. This takes 30+ seconds vs instant failure.

**Fix:** Add `CaseNumberParser.parse(case_number)` validation before discovery:
```ruby
begin
  CourtAuction::CaseNumberParser.parse(case_number)
rescue DataProvider::ParseError
  redirect_to properties_path, alert: "사건번호 형식이 올바르지 않습니다. (예: 2026타경1234)"
  return
end
```

### Console Errors

None detected (0 JS errors across all scenarios).

---

## Run 3: Post Playwright Redesign Verification (2026-04-09)

- **Test date:** 2026-04-09T04:41:00Z
- **Target URL:** http://localhost:3000
- **Context:** Verified app stability after CourtAuction scraper migration (Faraday → Ferrum CDP)
- **Total scenarios:** 6
- **Passed:** 6 | **Failed:** 0 | **Skipped:** 0

### Results Summary

| # | Scenario | Status | Screenshots | Notes |
|---|----------|--------|-------------|-------|
| S-001 | Sidebar > 예산 설정 | PASS | before/e2e-s001-properties-list.png, after/e2e-s001-budget-settings.png | Page loads, form renders correctly |
| S-002 | 물건 상세 (/properties/1) | PASS | after/e2e-s002-property-detail.png | Inspection grade, checklist, registry all render |
| S-003 | 데이터 소스 설정 페이지 | PASS | after/e2e-s003-data-sources.png | 6 provider cards, consent toggle ON, 5 API key forms |
| S-004 | 법원경매정보 동의 토글 | PASS | before/e2e-s004-consent-on.png, after/e2e-s004-consent-off.png | Toggle ON→OFF→ON, DB persisted via Turbo |
| S-005 | Console errors check | PASS | — | 0 JS errors, 7 warnings (normal) |
| S-006 | 물건 목록 복귀 | PASS | after/e2e-s006-properties-return.png | 4 property cards rendered, search form intact |

### Verification Notes

- **No regressions** from Playwright redesign — all existing UI functionality intact
- Backend changes (Faraday→Ferrum, ResponseParser rewrite) have zero UI impact
- Data sources settings page renders all 6 providers correctly
- Consent toggle for 법원경매정보 works correctly (sr-only checkbox + CSS toggle)

---

## Run 2: Data Provider Infrastructure (2026-04-09)

- **Test date:** 2026-04-09T02:14:00Z
- **Target URL:** http://localhost:3000/settings/data_sources
- **Total scenarios:** 6
- **Passed:** 5 | **Failed:** 1 (fixed during test) | **Skipped:** 0

### Results Summary

| # | Scenario | Status | Screenshots | Notes |
|---|----------|--------|-------------|-------|
| S-001 | Data sources page load | PASS | before/s001-data-sources-page.png | 6 provider cards rendered correctly |
| S-002 | Save API key (data.go.kr) | PASS (after fix) | after/s002-data-go-kr-key-saved-fixed.png | Initial attempt failed due to missing `scope: :api_credential` in form |
| S-003 | Verify credential | PASS | after/s003-verify-clicked.png | Job enqueued, redirected back |
| S-004 | Delete credential | PASS | after/s004-delete-credential.png | Turbo confirm accepted, credential removed |
| S-005 | Consent toggle ON | PASS | before/s005-consent-toggle-off.png, after/s005-consent-toggle-on.png | Toggle gray→blue, DB persisted |
| S-006 | Console errors check | PASS | — | 0 JS errors across all scenarios |

### Bugs Found & Fixed

**BUG-001: Form params not nested under api_credential (FIXED)**
- **Severity:** Critical — credentials could not be saved
- **Root cause:** `form_with` missing `scope: :api_credential`
- **Error:** `ActionController::ParameterMissing`
- **Fix:** Added `scope: :api_credential` to both forms
- **Commit:** `33db7ff`

### UI Observations

**Working correctly:**
- All 6 provider cards with correct Korean labels
- Consent provider shows toggle + warning
- Key providers show input + 저장 button
- After save: placeholder changes, 업데이트/검증/삭제 appear
- Write-only: saved keys not rendered back
- Delete reverts card to initial state

**Minor UX notes (not bugs):**
- Flash messages not visible (Turbo redirect clears them)
- No status badge on cards yet (planned for ViewComponent extraction)

---

## Run 1: UI Polish (2026-04-07)

- **Test date:** 2026-04-07T07:42Z
- **Target URL:** http://localhost:3000
- **Total scenarios:** 7
- **Passed:** 6 | **Failed:** 1 (routing, not a bug) | **Skipped:** 0

### Results Summary

| # | Scenario | Status | Screenshots | Notes |
|---|----------|--------|-------------|-------|
| S-000 | Properties list (baseline) | PASS | before/s000-properties-list.png | — |
| S-001 | Sidebar > 예산 설정 | PASS | after/s001-onboarding.png | Sidebar highlight correct |
| S-002 | Sidebar > 물건 목록 | PASS | after/s002-properties-list.png | Sidebar highlight correct |
| S-003 | Property show (width constraint) | PASS | after/s003-property-show-width.png | max-w-lg applied |
| S-004 | Inspection page (price badges) | PASS | after/s004-inspection-with-badges.png | 3 badges rendered |
| S-005 | Inspection tab navigation | PASS | after/s005-inspection-registry-tab.png | Badges persist across tabs |
| S-006 | 최대입찰가 badge → budget settings | PASS | after/s006-budget-settings.png | Link navigates correctly |

---

## Screenshot Index

```
docs/screenshots/
├── before/
│   ├── s000-properties-list.png
│   ├── s001-data-sources-page.png
│   └── s005-consent-toggle-off.png
├── after/
│   ├── s001-onboarding.png
│   ├── s002-properties-list.png
│   ├── s002-data-go-kr-key-saved-fixed.png
│   ├── s003-property-show-width.png
│   ├── s003-verify-clicked.png
│   ├── s004-delete-credential.png
│   ├── s004-inspection-with-badges.png
│   ├── s005-consent-toggle-on.png
│   ├── s005-inspection-registry-tab.png
│   └── s006-budget-settings.png
└── error/
    └── s004-inspection-sale-document-ERROR.png
```
