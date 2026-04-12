# E2E Beginner Test Report

**Date:** 2026-04-12
**Tester Persona:** First-time user (beginner)
**App:** Oh My Auction (http://localhost:3000)
**Environment:** Development (Rails 8.1, localhost)

---

## Test Target Inventory

| # | Element / Page | URL / Action | Type |
|---|---|---|---|
| 1 | Home page (`/`) | Redirects to `/properties` | Navigation |
| 2 | Properties list | `/properties` | Page |
| 3 | Budget settings (sidebar) | `/onboarding` -> redirects to `/settings/budget` | Navigation |
| 4 | Properties list (sidebar) | `/properties` | Navigation |
| 5 | AI Analysis (sidebar) | `/analyses/new` | Navigation |
| 6 | Report section (sidebar) | Disabled sub-items | Navigation |
| 7 | Guide section (sidebar) | Disabled sub-item | Navigation |
| 8 | Max bid link | `/settings/budget` | Link |
| 9 | Region combobox | Select region | Form |
| 10 | Case number search | Text input + button | Form |
| 11 | Condition search button | Search properties by region | Button |
| 12 | Property cards (list) | Click to view detail | Interactive |
| 13 | Property detail | `/properties/:id` | Page |
| 14 | Analysis results | `/properties/:id/inspections/tabs/rights_analysis/edit` | Page |
| 15 | Inspection grade | `/properties/:id/inspections/grade` | Page |
| 16 | Onboarding complete | `/onboarding/complete` | Page |
| 17 | Budget snapshots | `/settings/budget_snapshots` | Page |
| 18 | Budget snapshot detail | `/settings/budget_snapshots/:id` | Page |
| 19 | Search results | `/search_results` | Page |
| 20 | Analysis prompt | `/analyses/prompt` | Page (debug) |
| 21 | Data sources | `/settings/data_sources` -> redirects to `/analyses/new` | Page |
| 22 | AI auto-analysis tab | Button on `/analyses/new` | Tab |
| 23 | Manual analysis tab | Button on `/analyses/new` | Tab |
| 24 | Sidebar collapse/expand | Toggle button | Button |
| 25 | Theme toggle | Header icon button | Button |
| 26 | Delete property button | Per-property card | Button |
| 27 | Budget filter checkbox | "Budget range applied" toggle | Checkbox |

---

## Results Summary

| # | Scenario | Result | Notes |
|---|---|---|---|
| 1 | Home `/` loads | **PASS** | Redirects to `/properties` -- works |
| 2 | Properties list renders | **PASS** | Shows 4 properties with search/filter |
| 3 | Budget settings via sidebar | **PASS** | Loads full budget form |
| 4 | Properties list via sidebar | **PASS** | Navigation works |
| 5 | AI Analysis via sidebar | **PASS** | Shows PDF upload + tabs |
| 6 | Report sub-items | **SKIP** | All disabled (future feature) |
| 7 | Guide sub-item | **SKIP** | Disabled (future feature) |
| 8 | Max bid link | **PASS** | Links to budget settings |
| 9 | Region combobox | **PASS** | 19 regions available |
| 10 | Case number search | **PASS** | Input field renders correctly |
| 11 | Condition search results | **PASS** | Shows 3 search results |
| 12 | Property card click | **PASS** | Navigates to detail page |
| 13 | Property detail page | **PASS** | Shows case info + AI analysis links |
| 14 | Analysis results (rights) | **PASS** | 27/27 items, rich checklist UI |
| 15 | Inspection grade page | **PASS** | Full verdict, timeline, simulation |
| 16 | Onboarding complete | **PASS** | Budget summary displayed |
| 17 | Budget snapshots list | **PASS** | 13 versions with comparison tool |
| 18 | Budget snapshot detail | **PASS** | Cost breakdown shown |
| 19 | Search results page | **PASS** | 4 results displayed |
| 20 | Analysis prompt page | **PASS** | Raw JSON prompt (dev endpoint) |
| 21 | Data sources page | **PASS** | Redirects to AI analysis |
| 22 | AI auto-analysis tab | **PASS** | PDF upload UI shown |
| 23 | Manual analysis tab | **FAIL** | 404 error -- navigates to `/properties/99999` |
| 24 | Sidebar collapse/expand | **PASS** | Toggles correctly |
| 25 | Theme toggle (light/dark) | **PASS** | Switches to light mode |
| 26 | Delete property button | **SKIP** | Not tested (destructive action) |
| 27 | Budget filter checkbox | **SKIP** | Not tested |

**Totals: 21 PASS / 1 FAIL / 4 SKIP**

---

## Failure Details

### FAIL: Manual Analysis Tab (수동분석)

- **Page:** `/analyses/new`
- **Action:** Click "수동분석" tab button
- **Expected:** Switch to manual analysis form
- **Actual:** Navigates to `/properties/99999`, triggers `ActiveRecord::RecordNotFound in PropertiesController#show` with message "Couldn't find Property with 'id'=99999"
- **HTTP Status:** 404
- **Console Error:** `Failed to load resource: the server responded with a status of 404 (Not Found)`
- **Screenshot:** `docs/screenshots/error/manual-analysis-tab-ERROR.png`
- **Severity:** High -- this is a core feature tab that is completely broken for new users

---

## Screenshots Index

### Before (starting state)
| File | Description |
|---|---|
| `docs/screenshots/before/home-page.png` | Properties list (home page, full page) |
| `docs/screenshots/before/budget-settings-nav.png` | Before clicking budget settings |
| `docs/screenshots/before/property-detail-click.png` | Before clicking property detail |

### After (result state)
| File | Description |
|---|---|
| `docs/screenshots/after/budget-settings-nav.png` | Budget settings page (full form) |
| `docs/screenshots/after/properties-list-nav.png` | Properties list page |
| `docs/screenshots/after/ai-analysis-nav.png` | AI analysis page with PDF upload |
| `docs/screenshots/after/onboarding.png` | Onboarding redirects to budget settings |
| `docs/screenshots/after/onboarding-complete.png` | Onboarding complete with budget summary |
| `docs/screenshots/after/budget-snapshots.png` | Budget snapshots list (13 versions) |
| `docs/screenshots/after/data-sources.png` | Data sources redirects to AI analysis |
| `docs/screenshots/after/search-results.png` | Search results (4 items) |
| `docs/screenshots/after/analyses-prompt.png` | Analysis prompt (raw JSON) |
| `docs/screenshots/after/property-detail-95.png` | Property detail for 2024타경31432 |
| `docs/screenshots/after/analysis-results-95.png` | Analysis results (rights analysis, full) |
| `docs/screenshots/after/inspection-grade-95-fresh.png` | Inspection grade (comprehensive verdict) |
| `docs/screenshots/after/budget-snapshot-detail-13.png` | Budget snapshot v13 detail |
| `docs/screenshots/after/property-detail-89.png` | Unanalyzed property redirects to analysis |
| `docs/screenshots/after/header-button-1.png` | Light theme after toggle |
| `docs/screenshots/after/sidebar-collapsed.png` | Sidebar collapsed state |

### Error
| File | Description |
|---|---|
| `docs/screenshots/error/manual-analysis-tab-ERROR.png` | 404 error from manual analysis tab |
| `docs/screenshots/error/nonexistent-page-ERROR.png` | Standard routing error (expected) |

---

## Beginner UX Impressions

### What worked well
1. **Clear navigation structure** -- The sidebar groups features logically (Property Search, Budget, AI Analysis, Reports, Guide) with Korean labels that are easy to understand.
2. **Budget settings flow** -- The onboarding/budget setup page is thorough and well-organized. Auto-calculation of reserve costs based on property type and size is helpful.
3. **Property list is informative** -- Each card shows case number, failed auction count, appraisal price, minimum bid price, and address at a glance.
4. **AI analysis results are comprehensive** -- The checklist-based approach with Yes/No radio buttons, AI reasoning, and risk badges makes complex legal analysis accessible.
5. **Dark/light theme toggle** -- Works smoothly and respects user preference.
6. **Sidebar collapse** -- Clean toggle behavior, good for maximizing screen real estate.
7. **Legal disclaimer** -- Properly warns users that AI analysis is for reference only.

### What was confusing
1. **Manual analysis tab is broken** -- Clicking "수동분석" on the AI analysis page crashes with a 404. This would immediately frustrate a beginner trying to explore the app.
2. **Redirect behavior** -- `/onboarding` redirects to `/settings/budget` and `/settings/data_sources` redirects to `/analyses/new`. The sidebar label "예산 설정" links to `/onboarding`, but the page heading says "예산 설정". This indirection is invisible to the user but creates confusion in mental model.
3. **Disabled menu items without explanation** -- "순수익 계산기", "통합 시세 조회", "리포트 내보내기", and "명도 가이드" are all disabled with no tooltip or "coming soon" indicator explaining why.
4. **Header icon buttons lack labels** -- The three header buttons (theme toggle, etc.) are icon-only with no tooltips or aria-labels, making them hard to discover for beginners.
5. **Budget amounts inconsistency** -- On the inspection grade page, amounts show as "35700억원" (35,700 billion won) instead of "3억 5,700만원". This appears to be a formatting bug.
6. **Unanalyzed property redirect** -- When clicking on property 89 (unanalyzed), it redirects to the AI analysis page. A beginner might not understand why they were taken away from the property detail.
7. **No empty state guidance** -- The search/filter area doesn't explain what to do next if no properties match or how to add the first property.
