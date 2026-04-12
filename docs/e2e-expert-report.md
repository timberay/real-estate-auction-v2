# E2E Expert Test Report

**Date:** 2026-04-12  
**Tester:** Expert QA (Automated E2E via Playwright)  
**Target:** http://localhost:3000  
**App:** Oh My Auction (Real Estate Auction v2)

---

## 1. Test Target Inventory

| # | Route | Page Title | Status |
|---|-------|-----------|--------|
| 1 | `/` | Redirects to `/properties` | PASS |
| 2 | `/properties` | Properties List | PASS |
| 3 | `/properties/:id` (95) | Property Detail | PASS |
| 4 | `/properties/95/inspections/grade` | Inspection Grade | PASS (with currency bugs) |
| 5 | `/properties/95/inspections/tabs/rights_analysis/edit` | Rights Analysis Checklist | PASS |
| 6 | `/onboarding` | Redirects to `/settings/budget` | PASS |
| 7 | `/onboarding/complete` | Onboarding Complete | PASS |
| 8 | `/settings/budget` | Budget Settings | PASS |
| 9 | `/settings/budget_snapshots` | Budget Snapshots List | PASS (with display bug) |
| 10 | `/settings/budget_snapshots/compare` (via form) | Snapshot Compare | PASS |
| 11 | `/settings/budget_snapshots/compare` (via URL params) | Snapshot Compare | FAIL |
| 12 | `/settings/data_sources` | Data Sources Settings | PASS |
| 13 | `/analyses/new` | AI Analysis (Auto tab) | PASS |
| 14 | `/analyses/new` (Manual tab) | AI Analysis (Manual tab) | PASS |
| 15 | `/analyses/prompt` | Redirects to `/analyses/new` | PASS |
| 16 | `/search_results` | Search Results | PASS |

### Interactive Elements Tested

| Element | Location | Test | Result |
|---------|----------|------|--------|
| Sidebar nav links (3) | All pages | Click navigation | PASS |
| Sidebar toggle | All pages | Expand/collapse | PASS |
| Hamburger menu (mobile) | Mobile viewport | Open menu | PASS (overlap issue) |
| Region dropdown | Properties | Select region | PASS |
| Case number input + add button | Properties | Submit empty | PASS (no crash) |
| Search textbox + button | Properties | Filter by text | PASS |
| Safety rating dropdown | Properties | Filter by rating | PASS |
| Budget toggle checkbox | Properties | Toggle on/off | PASS (click target issue) |
| Property cards (4) | Properties | Click to detail | PASS |
| Delete buttons (4) | Properties | Not tested (destructive) | SKIP |
| Budget form fields | Budget Settings | Edit values | PASS |
| Auto-calc checkbox | Budget Settings | Toggle | PASS |
| Loan policy radio buttons | Budget Settings | Select | PASS |
| Snapshot compare form | Budget Snapshots | Submit compare | PASS |
| API key save buttons (5) | Data Sources | Submit empty | PASS |
| File upload button | Analyses | Present, not tested | SKIP |
| Tab buttons (Auto/Manual) | Analyses | Switch tabs | PASS |
| Inspection tab links (6) | Property Detail | Navigate | PASS |

---

## 2. Results Summary

| Category | PASS | FAIL | SKIP | Total |
|----------|------|------|------|-------|
| Navigation | 14 | 0 | 0 | 14 |
| Form Validation | 3 | 1 | 1 | 5 |
| Error Handling | 1 | 2 | 0 | 3 |
| Data Display | 2 | 2 | 0 | 4 |
| Responsive | 3 | 0 | 0 | 3 |
| Console Errors | 1 | 0 | 0 | 1 |
| **Total** | **24** | **5** | **1** | **30** |

---

## 3. Failure Details

### F01: Negative Budget Value Accepted (High)

- **Severity:** High
- **Page:** `/settings/budget`
- **Steps to reproduce:**
  1. Navigate to `/settings/budget`
  2. Clear the "유용자금" field
  3. Enter `-5000`
  4. Observe the "현재 최대입찰가" value
- **Expected:** Negative values should be rejected or treated as 0
- **Actual:** Max bid increases from 2억 2,700만원 to 4억 2,700만원 (negative budget subtracts from expenses, inflating the result)
- **Screenshot:** `docs/screenshots/error/expert-negative-budget-ERROR.png`

### F02: Snapshot Compare Crashes with Direct URL Params (High)

- **Severity:** High
- **Page:** `/settings/budget_snapshots/compare?base_id=13&compare_id=1`
- **Steps to reproduce:**
  1. Navigate to the URL directly with `base_id` and `compare_id` params
- **Expected:** Should handle alternate param formats gracefully or redirect
- **Actual:** `NoMethodError: undefined method '[]' for nil` in `BudgetSnapshotsController#compare` at line 13. Controller expects `params[:ids]` array but receives separate params.
- **Screenshot:** `docs/screenshots/error/expert-snapshot-compare-ERROR.png`
- **Code location:** `/app/controllers/settings/budget_snapshots_controller.rb:13`

### F03: Currency Formatting Bug in Inspection Grade Report (High)

- **Severity:** High
- **Page:** `/properties/95/inspections/grade`
- **Steps to reproduce:**
  1. Navigate to property 95 inspection grade page
  2. Look at the "권리 분석 리포트" section
- **Expected:** Amounts formatted as Korean currency (e.g., "3억 5,700만원")
- **Actual:** Shows "감정가: 35700억원", "최저매각가: 35700억원", "총 위험 금액: 32440억원" -- amounts are displayed in 억원 unit without proper conversion, making the numbers appear ~10,000x larger than they are
- **Screenshot:** `docs/screenshots/error/expert-currency-formatting-ERROR.png`

### F04: Budget Snapshot Amounts Display as Raw Numbers (Medium)

- **Severity:** Medium
- **Page:** `/settings/budget_snapshots`
- **Steps to reproduce:**
  1. Navigate to `/settings/budget_snapshots`
  2. Look at the snapshot list amounts
- **Expected:** Formatted as Korean currency (e.g., "2억 2,700만원")
- **Actual:** Shows "22,700원" (raw number in 원) instead of formatted currency
- **Screenshot:** `docs/screenshots/after/expert-budget-snapshots.png`

### F05: No Custom 404/Error Pages (Medium)

- **Severity:** Medium
- **Pages:** `/properties/99999`, `/nonexistent-route`
- **Steps to reproduce:**
  1. Navigate to any non-existent route
- **Expected:** User-friendly error page
- **Actual:** Raw Rails error page showing stack traces (ActiveRecord::RecordNotFound, RoutingError). While this is normal in development mode, there should be custom error pages for production.
- **Screenshots:** `docs/screenshots/error/expert-property-404-ERROR.png`, `docs/screenshots/error/expert-nonexistent-route-ERROR.png`

---

## 4. Edge Case Findings

| Test | Input | Result | Severity |
|------|-------|--------|----------|
| Empty budget field | blank | Max bid shows "—" | OK (handled) |
| Text in budget field | "abc" | Max bid shows "—" | OK (handled) |
| Negative budget | -5000 | Max bid inflated | **High** |
| LTV = 999 | 999 | Max bid shows "—" | OK (handled) |
| Empty case number submit | blank | No crash | OK |
| Empty API key save | blank | Accepted silently | Low (could warn) |
| Non-existent property ID | /properties/99999 | Rails error page | **Medium** |
| Non-existent route | /nonexistent-route | Rails routing error | **Medium** |
| Invalid compare params | base_id & compare_id | Server crash (500) | **High** |
| Invalid search params | /search_results?foo=bar | No crash, shows page | OK |

---

## 5. Responsive Issues

| Viewport | Issue | Severity |
|----------|-------|----------|
| Desktop (1920x1080) | No issues found | - |
| Tablet (768x1024) | Sidebar collapses to icons correctly; 2-column grid layout works | - |
| Mobile (375x812) | Sidebar hamburger menu overlaps with main content when open (sidebar slides out but content is not pushed/overlaid) | **Low** |
| Mobile (375x812) | Inspection tabs overflow horizontally (has `overflow-x-auto`, acceptable) | - |
| Mobile (375x812) | Budget settings page renders well, forms are usable | - |
| Mobile (375x812) | Property detail and cards render properly in single column | - |

---

## 6. Console Error Log

Only 2 JS console errors detected during the entire test session, both from intentional edge case testing:

1. `Failed to load resource: 404 (Not Found)` -- `/nonexistent-page` (expected)
2. `Failed to load resource: 500 (Internal Server Error)` -- `/settings/budget_snapshots/compare?base_id=13&compare_id=1` (bug F02)

**CSS preload warnings** (2): Application and Tailwind CSS files are preloaded but not consumed within the expected timeframe. Low priority.

No JavaScript runtime errors were detected on any valid page.

---

## 7. Additional Observations

1. **Search results page formatting**: The `/search_results` page shows amounts as raw numbers (e.g., "302,000,000") instead of Korean formatted currency ("3억 200만원"). This is inconsistent with the properties list page which formats correctly.

2. **Budget checkbox sr-only**: The "예산 범위 적용" checkbox uses `sr-only` class and the label span intercepts pointer events. While the wrapper div is clickable, this could cause accessibility testing tools to flag it.

3. **Sidebar section headings** ("물건검색", "리포트", "가이드") collapse/expand their sub-items. When sidebar is collapsed to icons only, the section headings disappear and only icons remain, which works correctly.

4. **Disabled buttons**: "순수익 계산기", "통합 시세 조회", "리포트 내보내기", and "명도 가이드" are all disabled. This is expected for MVP features not yet implemented.

5. **Route redirects**: `/` -> `/properties`, `/onboarding` -> `/settings/budget`, `/analyses/prompt` -> `/analyses/new`. All redirects work correctly.

---

## 8. Screenshot Index

### Before
- `docs/screenshots/before/expert-home-page.png` -- Properties list (initial state)
- `docs/screenshots/before/expert-nav-budget-settings.png` -- Before nav click

### After (successful)
- `docs/screenshots/after/expert-settings-budget.png` -- Budget settings page
- `docs/screenshots/after/expert-onboarding-complete.png` -- Onboarding complete
- `docs/screenshots/after/expert-budget-snapshots.png` -- Snapshot list
- `docs/screenshots/after/expert-analyses-new.png` -- AI Analysis page
- `docs/screenshots/after/expert-manual-analysis-tab.png` -- Manual analysis tab
- `docs/screenshots/after/expert-search-results.png` -- Search results
- `docs/screenshots/after/expert-data-sources.png` -- Data sources settings
- `docs/screenshots/after/expert-analyses-prompt.png` -- Analyses prompt redirect
- `docs/screenshots/after/expert-property-detail-95.png` -- Property detail
- `docs/screenshots/after/expert-search-results-invalid-params.png` -- Search with invalid params
- `docs/screenshots/after/expert-empty-case-number-submit.png` -- Empty case submit
- `docs/screenshots/after/expert-empty-api-key-save.png` -- Empty API key save
- `docs/screenshots/after/expert-desktop-1920x1080.png` -- Desktop viewport
- `docs/screenshots/after/expert-tablet-768x1024.png` -- Tablet viewport
- `docs/screenshots/after/expert-mobile-375x812.png` -- Mobile viewport
- `docs/screenshots/after/expert-mobile-hamburger-open.png` -- Mobile hamburger menu
- `docs/screenshots/after/expert-mobile-budget-settings.png` -- Mobile budget settings
- `docs/screenshots/after/expert-mobile-property-detail.png` -- Mobile property detail
- `docs/screenshots/after/expert-mobile-inspection-grade.png` -- Mobile inspection grade
- `docs/screenshots/after/expert-snapshot-compare-success.png` -- Snapshot compare (success)
- `docs/screenshots/after/expert-budget-filter-on.png` -- Budget filter active
- `docs/screenshots/after/expert-search-filter-seocho.png` -- Text search filter
- `docs/screenshots/after/expert-sidebar-expanded.png` -- Sidebar expanded
- `docs/screenshots/after/expert-rights-analysis-tab.png` -- Rights analysis checklist

### Errors
- `docs/screenshots/error/expert-property-404-ERROR.png` -- Property 404 error
- `docs/screenshots/error/expert-nonexistent-route-ERROR.png` -- Routing error
- `docs/screenshots/error/expert-negative-budget-ERROR.png` -- Negative budget bug
- `docs/screenshots/error/expert-snapshot-compare-ERROR.png` -- Compare crash
- `docs/screenshots/error/expert-currency-formatting-ERROR.png` -- Currency format bug
