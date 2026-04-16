# Beginner E2E Test Results

- Test date: 2026-04-16
- Tester: Beginner Agent
- Base URL: http://localhost:3000

## Test Target Inventory

| # | Element | Type | Location | URL/Action |
|---|---------|------|----------|------------|
| 1 | Home (`/`) | Page | Root URL | Redirects to `/properties` |
| 2 | 예산 설정 (Budget Settings) | Sidebar Nav Link | Left sidebar | `/onboarding` -> redirects to `/settings/budget` |
| 3 | 물건 목록 (Property List) | Sidebar Nav Link | Left sidebar | `/properties` |
| 4 | AI분석 (AI Analysis) | Sidebar Nav Link | Left sidebar | `/analyses/new` |
| 5 | 명도 가이드 (Eviction Guide) | Sidebar Nav Link | Left sidebar | `/eviction_guide` |
| 6 | 명도 시뮬레이터 (Eviction Simulator) | Sidebar Nav Link | Left sidebar | `/eviction_guide/simulator` |
| 7 | 최대입찰가 (Max Bid Badge) | Header Link | Top-right of properties page | `/settings/budget` |
| 8 | 다크 모드 전환 (Dark Mode Toggle) | Header Button | Top-right corner | Toggles dark/light mode |
| 9 | 사이드바 접기/펼치기 (Sidebar Collapse) | Sidebar Button | Bottom of sidebar | Collapses sidebar to icon-only |
| 10 | Onboarding Direct | Page | Direct URL | `/onboarding` -> `/settings/budget` |
| 11 | Search Results | Page | Direct URL | `/search_results` |
| 12 | Health Check | Page | Direct URL | `/up` |
| 13 | Eviction Step S1 | Accordion | Eviction guide page | Expands step content |
| 14 | Eviction Branch B1 | Accordion | Inside S1 step | Expands branch content |
| 15 | Property Detail | Page | Property list link | `/properties/33` -> `/analyses/new?property_id=33` |
| 16 | Manual Analysis Tab | Tab | AI Analysis page | Switches to manual analysis mode |
| 17 | Simulator Tab Link | Tab | Eviction guide in-content | `/eviction_guide/simulator` |
| 18 | Simulator Direct Input | Button | Simulator page | `/eviction_guide/simulator/select_type` |
| 19 | Simulator Occupant Selection | Button | Type selection page | `/eviction_guide/simulator/question/JT-Q1` |
| 20 | 404 Page | Page | Non-existent URL | Rails dev routing error |

## Results

| # | Scenario | Status | Console Errors | Screenshots | Notes |
|---|----------|--------|----------------|-------------|-------|
| B-001 | Home (`/`) redirect | PASS | N | before/B-001-home.png, after/B-001-home.png | `/` redirects to `/properties`. Page shows search, saved properties list with 5 items, and 20 search results |
| B-002 | GNB - 예산 설정 | PASS | N | before/B-002-gnb-onboarding.png, after/B-002-gnb-onboarding.png | Nav link `/onboarding` redirects to `/settings/budget`. Shows budget form with region, available funds, reserve costs, loan policy |
| B-003 | GNB - 물건 목록 | PASS | N | before/B-003-gnb-properties.png, after/B-003-gnb-properties.png | Navigates to `/properties` correctly |
| B-004 | GNB - AI분석 | PASS | N | before/B-004-gnb-ai-analysis.png, after/B-004-gnb-ai-analysis.png | Navigates to `/analyses/new`. Shows PDF upload form with AI auto-analysis and manual analysis tabs |
| B-005 | GNB - 명도 가이드 | PASS | N | before/B-005-gnb-eviction-guide.png, after/B-005-gnb-eviction-guide.png | Shows 15 main steps (S1-S15) + 6 junior tenant steps (JT-S1 to JT-S6), intro section, CTA to simulator |
| B-006 | GNB - 명도 시뮬레이터 | PASS | N | before/B-006-gnb-eviction-simulator.png, after/B-006-gnb-eviction-simulator.png | Shows two simulation modes (my property / direct input), property selector with 5 analyzed properties |
| B-007 | 최대입찰가 budget link | PASS | N | before/B-007-budget-link.png, after/B-007-budget-link.png | Links to `/settings/budget`, same as 예산 설정 |
| B-008 | Dark mode toggle | PASS | N | before/B-008-dark-mode-toggle.png, after/B-008-dark-mode-toggle.png | Successfully toggles from dark to light mode. Colors invert, icon changes. Toggle back works too |
| B-009 | Sidebar collapse/expand | PASS | N | before/B-009-sidebar-toggle.png, after/B-009-sidebar-toggle.png | Sidebar collapses to icon-only mode. Main content area expands. Expand button restores full sidebar |
| B-010 | Onboarding direct URL | PASS | N | before/B-010-onboarding-direct.png, after/B-010-onboarding-direct.png | `/onboarding` redirects to `/settings/budget` (same budget settings page) |
| B-011 | Search Results page | PASS | N | before/B-011-search-results.png, after/B-011-search-results.png | `/search_results` loads with 27 cached search results. Each item shows address, case number, court, appraisal/minimum prices |
| B-012 | Health Check | PASS | N | before/B-012-health-check.png, after/B-012-health-check.png | `/up` returns green page (HTTP 200 OK) |
| B-013 | Eviction Guide - Step S1 | PASS | N | before/B-013-eviction-step-s1.png, after/B-013-eviction-step-s1.png | S1 accordion expands showing description, required documents, completion/failure conditions, and branch links (B1, B2, B3) |
| B-014 | Eviction Guide - Branch B1 | PASS | N | before/B-014-eviction-branch-b1.png, after/B-014-eviction-branch-b1.png | B1 accordion expands inside S1 showing detailed scenario (deposit risk), situation, root cause, countermeasures |
| B-015 | Property Detail page | PASS | N | before/B-015-property-detail.png, after/B-015-property-detail.png | `/properties/33` redirects to `/analyses/new?property_id=33` with property info header (case number + address) |
| B-016 | Manual Analysis Tab | PASS | N | before/B-016-manual-analysis-tab.png, after/B-016-manual-analysis-tab.png | Manual tab shows prompt copy section and JSON result upload section |
| B-017 | Simulator Tab Link | PASS | N | before/B-017-simulator-link.png, after/B-017-simulator-link.png | In-content tab link navigates to simulator page correctly |
| B-018 | Simulator Direct Input | PASS | N | before/B-018-simulator-direct-input.png, after/B-018-simulator-direct-input.png | Direct input mode shows 4 occupant types with difficulty levels (low/medium/high) |
| B-019 | Simulator Question Flow | PASS | N | before/B-019-simulator-occupant-selection.png, after/B-019-simulator-occupant-selection.png | Selecting occupant type leads to question page with progress bar, occupant badge, Yes/No options, legal basis section |
| B-020 | 404 / Non-existent URL | INFO | Y (1) | before/B-020-404-page.png, after/B-020-404-page.png, error/B-020-404-page-ERROR.png | Rails dev mode routing error page shown. No custom 404 page. Console: 404 status error. Expected behavior in development |

## Failure Details

No functional failures found. All 19 main test scenarios passed.

### Note on B-020 (404 page)

- **Expected**: A user-friendly 404 error page
- **Actual**: Rails development mode routing error page with full route table exposed
- **Impact**: Low (development only, production would show standard Rails 404)
- **Recommendation**: Consider adding a custom 404 page for production
- **Screenshot**: `error/B-020-404-page-ERROR.png`

## Observations

### Navigation Structure
- **Sidebar (GNB)**: 5 main navigation items in 2 groups:
  - Group 1: 예산 설정, 물건 목록, AI분석
  - Group 2: 명도 가이드, 명도 시뮬레이터
- **Header**: App title (부동산 경매 도우미), breadcrumb with page title, dark mode toggle
- **Footer**: Simple copyright notice on all pages

### Redirect Behavior
- `/` -> `/properties` (home redirects to properties list)
- `/onboarding` -> `/settings/budget` (onboarding redirects to budget settings)
- `/properties/:id` -> `/analyses/new?property_id=:id` (property detail redirects to AI analysis)

### Key UI Features Found
1. **Dark/Light Mode**: Toggle works correctly, preserves across navigation
2. **Collapsible Sidebar**: Smooth transition to icon-only mode
3. **Budget Badge**: Shows max bid amount on properties page, links to settings
4. **Skip to Content Link**: Accessibility feature present ("본문으로 건너뛰기")
5. **Search Results Caching**: 27 results cached from previous condition search (20 from search + 7 additional from 부산 court)
6. **Eviction Guide Accordion**: Steps and branches expand/collapse smoothly
7. **Simulator Decision Tree**: Multi-step question flow with progress tracking

### Console Errors Summary
- **Total Pages Tested**: 20
- **Pages with Console Errors**: 1 (B-020, the intentional 404 test)
- **Pages with Console Warnings**: 2 (B-006, B-017 - simulator pages, 2 warnings each, not errors)
- **Zero errors on all functional pages**

## Summary

- Total: 20
- Passed: 19
- Failed: 0
- Info: 1 (404 page - dev mode routing error, not a functional failure)
- Skipped: 0
