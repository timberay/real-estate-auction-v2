# Expert E2E Test Results

- Test date: 2026-04-16
- Tester: Expert Agent
- Base URL: http://localhost:3000

## Results
| # | Scenario | Status | Console Errors | Screenshots | Notes |
|---|----------|--------|----------------|-------------|-------|
| E-001 | Budget Settings - full form | PASS | N | before/E-001-settings-budget.png, after/E-001-settings-budget-after-interaction.png | Region selector (19 options), budget input, reserve costs (5 sub-fields with auto-calc), loan policy radio, max bid display. Reactive form updates correctly. |
| E-002 | Data Sources Settings | PASS | N | before/E-002-settings-data-sources.png | One data source (court auction) with consent checkbox and warning. Minimal but functional. |
| E-003 | New Analysis - AI Auto tab | PASS | N | before/E-003-analyses-new.png | Two tabs (AI auto, Manual), PDF upload with file chooser, disabled start button until file selected. |
| E-004 | Analysis Prompt page | PASS | N | before/E-004-analyses-prompt.png | Raw JSON prompt with all checklist items. Has pretty print checkbox. |
| E-005 | Eviction Simulator - Select Type | PASS | N | before/E-005-eviction-select-type.png | 4 occupant types with difficulty badges: junior tenant (low), senior tenant (high), debtor (medium), illegal occupant (high). |
| E-006 | Eviction - JT-Q1 Question | PASS | N | before/E-006-eviction-JT-Q1.png | Progress bar (0%), occupant type badge, step indicator, question text, Yes/No buttons with green/red borders, legal basis expandable. |
| E-007 | Eviction - JT-Q2 to JT-Q5 flow | PASS | N | before/E-007-eviction-JT-Q2.png | Progress advances correctly: 17%, 33%, 50%, 67%, 83%. Each question has contextual content. |
| E-008 | Eviction - Simulation Result | PASS | N | after/E-008-eviction-simulation-result.png | Shows occupant type, difficulty, full path with 6 completed steps, stats (6 total, 0 branches), legal disclaimer. |
| E-009 | Eviction - Progress Reset Bug | FAIL | N | error/E-009-eviction-progress-not-reset-BUG.png | Re-entering simulator after completing a flow shows 100% progress on first question instead of 0%. Session state not reset. |
| E-010 | Eviction - Branch Path (No answer) | PASS | N | before/E-010-eviction-branch-JT-Q1G.png | Answering "No" on JT-Q1 navigates to branch question JT-Q1G with different question text. Branch flow works. |
| E-011 | Eviction Guide - Main page | PASS | N | before/E-011-eviction-guide-main.png | Intro section, simulator CTA, 15 general steps (S1-S15) + 6 JT steps with durations, legal disclaimer. |
| E-012 | Eviction Guide - Step Accordion | PASS | N | before/E-012-eviction-branch-B1-detail.png | S1 expands to show description, required docs, completion criteria, 3 branch options (B1-B3). Branch B1 also expands inline. |
| E-013 | Eviction - Step Detail Page | PASS | N | before/E-013-eviction-step-S1-detail.png | /eviction_guide/steps/S1 shows step name only. Minimal but loads without error. |
| E-014 | Eviction - Branch Detail Page | PASS | N | before/E-014-eviction-branch-B1-page.png | /eviction_guide/branches/B1 shows branch name only. Minimal but loads without error. |
| E-015 | Eviction Simulator - Landing | PASS | N | before/E-015-eviction-prefill.png | Two mode options: "My property" (with 5 properties in dropdown) and "Manual input". |
| E-016 | Eviction Simulator - Prefill Form | PASS | N | before/E-016-eviction-prefill-form.png | After selecting a property, shows occupant type radio selection with 4 options. Data from F02 analysis. |
| E-017 | Properties List | PASS | N | before/E-017-properties-list.png | Max bid link, region selector, case number input, search results grid (20 items), 5 saved properties with badges, filter, budget toggle. |
| E-018 | Property Detail (redirect) | PASS | N | before/E-018-property-detail-redirect.png | /properties/:id redirects to analyses/new?property_id=:id. Shows property context at top. |
| E-019 | 404 - Nonexistent Route | PASS | Y (404) | error/E-019-nonexistent-route.png | Rails dev error "Routing Error" with routes table. Expected in dev mode. |
| E-020 | 404 - Property Not Found | PASS | Y (404) | error/E-020-property-not-found.png | Rails dev error "ActiveRecord::RecordNotFound" with source code. Expected in dev mode. |
| E-021 | Dark/Light Mode Toggle | PASS | N | after/E-021-light-mode.png | Toggle works. Light mode has clean white background with blue accents. |
| E-022 | Eviction - Debtor Type Flow | PASS | N | before/E-022-eviction-debtor-Q1.png | Debtor type starts at Q1 (general flow) with correct badge. Progress resets to 0%. |
| E-023 | Eviction - Senior Tenant Type | PASS | N | -- | Senior tenant starts at Q1 with "Senior tenant (opposing power)" badge. Verified. |
| E-024 | Eviction - Illegal Occupant Type | PASS | N | -- | Illegal occupant starts at Q1 with correct badge. All 4 types verified. |
| E-025 | Accessibility - Skip to Content | PASS | N | -- | Skip link exists, target #main-content ID resolves to <main> tag. |
| E-026 | Manual Analysis Tab | PASS | N | after/E-003-analyses-manual-tab.png | Prompt copy button and JSON upload/paste with save button. Two-section layout. |

## Failure Details

### E-009: Simulator Progress Bar Not Reset on Re-entry
- **Expected**: When starting a new simulation after completing a previous one, progress should reset to 0%
- **Actual**: Progress bar shows 100% on the first question (JT-Q1) when re-entering the simulator
- **Impact**: Confusing UX -- user sees full progress bar despite being on the first question
- **Reproduction**: Complete a full JT simulation (all Yes), then go back to select_type, select same type again
- **Root cause hypothesis**: Session/cookie stores previous simulation state and is not cleared when starting a new simulation

## Form Interaction Results

### Budget Settings (`/settings/budget`)
- **Region selector**: 19 options (all Korean provinces/cities). Selecting Seoul works via standard dropdown.
- **Budget input**: Text field with "3,000" value, unit "man won" suffix.
- **Property type dropdown**: 3 options (apartment, villa, officetel).
- **Area dropdown**: 5 size options + placeholder.
- **Auto-calc checkbox**: Toggles auto-calculation of reserve costs. When unchecked, fields become editable.
- **Reserve cost fields**: 5 spinbutton inputs (repair, acquisition tax, legal fees, moving costs, unpaid fees). Auto-calculated values update based on property type/area.
- **Reserve total**: Displays calculated sum (1,038 man won).
- **Loan policy radios**: Two options (1st tier 80% LTV, 2nd tier 90% LTV). Switching updates LTV value and max bid automatically.
- **Max bid display**: Reactive calculation -- changes from 1억 9,620만원 (90% LTV) to 9,810만원 (80% LTV) on loan policy change.
- **Submit button**: Present with checkmark icon.

### Analyses (`/analyses/new`)
- **Tab switching**: AI Auto vs Manual tabs work correctly.
- **AI Auto tab**: PDF file upload with disabled "Start Analysis" button (enables only after file selection).
- **Manual tab**: "Copy Prompt" button (clipboard) + "Upload File"/"Paste" toggle for JSON results + disabled "Save" button.

### Eviction Simulator
- **4 occupant types**: All navigate to correct question flows (JT-* for junior tenant, Q* for others).
- **Yes/No buttons**: Green (Yes) and Red (No) bordered buttons with clear labels.
- **Branch questions**: Answering "No" leads to branch-specific follow-up questions (e.g., JT-Q1G).
- **Legal basis expandable**: Details with law references and external link to law.go.kr.
- **Progress bar**: Advances correctly through the flow (0%, 17%, 33%, 50%, 67%, 83%, 100%).
- **Prefill form**: Radio selection for occupant type when entering via property selection.

### Properties (`/properties`)
- **Region filter**: Dropdown + search button.
- **Case number input**: Text input + "Add" button.
- **Search results**: Grid layout with case number, appraisal price, minimum bid, address.
- **Saved properties**: Card layout with case number links, status badges, price info, delete buttons.
- **Filter bar**: Risk level dropdown, text search, budget range toggle.

## Summary
- Total: 26
- Passed: 25
- Failed: 1
- Skipped: 0

### Key Findings
1. **BUG**: Simulator progress bar not reset when re-entering after completion (E-009)
2. All 4 occupant type flows work correctly with appropriate badges
3. Budget settings form is fully reactive (loan policy, auto-calc, max bid all update in real-time)
4. Property detail pages redirect to analysis page (no standalone detail view)
5. Error handling uses Rails dev-mode error pages (expected, but production would need custom 404/500)
6. Dark/light mode toggle works across all pages
7. Accessibility: Skip-to-content link and main landmark present
8. Step/branch detail pages (/steps/:code, /branches/:code) are minimal (name only) vs rich accordion view on main guide page
