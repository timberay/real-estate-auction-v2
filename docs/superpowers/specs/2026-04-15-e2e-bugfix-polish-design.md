# E2E Bugfix & Polish Design

> Scope: Fix bugs and remove unfinished UI elements found during the Run 7 dual-persona E2E audit (2026-04-15).
> Approach: Option B (bugs + unfinished cleanup), file-based grouping (Option A ordering).

## Context

Full-app E2E audit with beginner and expert personas found 14 issues.
This spec covers the 7 actionable tasks within the agreed scope — bug fixes and
placeholder cleanup. UX-level improvements (onboarding, property detail page) are
out of scope.

Reference: `docs/e2e-test-report.md` — Run 7.

## Task 1: Remove notification and user menu buttons from header

**Issue**: H-3, H-4 — buttons do nothing when clicked. Unfinished features that
hurt perceived quality.

**Decision**: Full removal (not hide/disable). Re-add in post-MVP when implemented.

**Changes**:
- `app/components/header/component.html.erb` lines 23–29: delete the two `<button>` elements (알림, 사용자 메뉴)
- Keep `<span id="analysis_indicator">` (line 21) — it serves the AI analysis status indicator

**Test**: Visual check — header should show only dark mode toggle and analysis indicator.

## Task 2: Defensive fix for dark mode toggle navigation bug

**Issue**: H-5 — first click on dark mode toggle from `/properties` navigated to
`/settings/budget`. Likely caused by Turbo cache state + event bubbling.

**Changes**:
- `app/javascript/controllers/dark_mode_controller.js` line 10:
  change `toggle()` → `toggle(event)` and add `event.preventDefault(); event.stopPropagation();`

**Test**: Click dark mode toggle on `/properties` — page must stay on `/properties`,
theme must change.

## Task 3: Unify app title to Korean

**Issue**: L-1 — header shows "Real Estate Auction" while all UI is Korean.

**Changes**:
- Find where `@app_name` is set in `app/components/header/component.rb` and change
  the default value to a Korean title (e.g. "부동산 경매 도우미" or similar)
- If `@app_name` is hardcoded in the ERB, change it there

**Test**: All pages should display Korean app title in header.

## Task 4: Case number form client-side validation

**Issue**: H-1 — submitting empty or invalid case number produces zero feedback.

**Changes**:
- `app/views/properties/index.html.erb`: add `required` attribute to the case number
  `<input>` element
- `app/javascript/controllers/criteria_search_controller.js` `submitCaseNumber()`:
  add empty-value check at the start. If blank, prevent submission and show inline
  error message "사건번호를 입력해주세요" near the input field
- Server-side flash validation in `properties_controller.rb` lines 49–51 stays as-is
  (fallback for JS-disabled clients)
- No format regex — case number formats vary (`타경`, `카단`, etc.) and the server
  validates via DB lookup

**Test**:
1. Empty input + click 추가 → inline error shown, no server request
2. Valid case number → form submits normally
3. Non-existent case number → server flash error displayed

## Task 5: Fix eviction simulator "내 물건" mode Turbo error

**Issue**: H-2 — `SimulationsController#create` renders instead of redirecting when
`property_linked?` is true. Turbo requires POST responses to redirect.

**Changes**:
- `config/routes.rb` line 66: inside `namespace :eviction_guide` block, add:
  ```ruby
  get "simulator/prefill", to: "simulations#prefill", as: :simulator_prefill
  ```
  This generates helper `eviction_guide_simulator_prefill_path` → `GET /eviction_guide/simulator/prefill`
- `app/controllers/eviction_guide/simulations_controller.rb`:
  - `create` action (line 20–23): replace `render "prefill"` with
    `redirect_to eviction_guide_simulator_prefill_path`
  - Add new `prefill` GET action that loads `@simulation` from session,
    sets `@property` and `@prefill_data`, and renders the existing
    `eviction_guide/simulator/prefill` template
- No changes to the prefill template itself

**Test**: "내 물건으로 시뮬레이션" → "확인 완료 → 시뮬레이션 시작" → prefill page
loads without Turbo error → simulation proceeds to Q1.

## Task 6: Investigate and fix console 404 for /onboarding/step1

**Issue**: M-3 — console shows 404 for `/onboarding/step1` on budget settings page.
No direct reference found in settings views or JS. Likely Turbo prefetch or browser
cache artifact.

**Changes**:
- Reproduce with Playwright on `/settings/budget`, check network/console
- If reproducible: add `get :step1` route that redirects to `start_onboarding_path`,
  or add `data-turbo-prefetch="false"` to the relevant link
- If not reproducible: document as E2E-environment-only artifact and skip

**Test**: Navigate to `/settings/budget`, check console — no 404 errors.

## Task 7: E2E re-verification

After Tasks 1–6 are complete, run Playwright verification for all changed areas:

| Check | Expected |
|-------|----------|
| Header buttons | Only dark mode toggle + analysis indicator visible |
| Dark mode toggle on /properties | Theme changes, page stays |
| App title | Korean text displayed |
| Empty case number submit | Inline error shown |
| Simulator "내 물건" mode | Prefill page loads, simulation completes |
| Console errors on /settings/budget | No 404 |

Capture before/after screenshots to `docs/screenshots/`.

## Out of Scope

These items from the E2E report are explicitly excluded:

- M-1: Onboarding/welcome screen for first-time users
- M-2: Basic property detail page for unanalyzed properties
- M-4: Region select redirect behavior (investigated — actually working correctly with fetch + "✓ 저장됨" feedback)
- L-2 through L-5: Polish items (sidebar labels, search reset, back button, tooltips)
