# E2E Bugfix & Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 5 bugs and clean up 2 unfinished UI elements found during the Run 7 dual-persona E2E audit.

**Architecture:** Isolated, file-grouped changes — header cleanup (Tasks 1–3), form validation (Task 4), Turbo redirect fix (Task 5), stale route fix (Task 6), then E2E re-verification (Task 7). Each task is independently committable.

**Tech Stack:** Rails 8.1, ViewComponent, Stimulus, Hotwire/Turbo, Minitest, Playwright MCP

**Spec:** `docs/superpowers/specs/2026-04-15-e2e-bugfix-polish-design.md`

---

### Task 1: Remove notification and user menu buttons from header

**Files:**
- Modify: `app/components/header/component.html.erb:23-29`
- Modify: `app/components/header/component.rb:42-58`
- Modify: `test/components/header/component_test.rb:100-113`

- [ ] **Step 1: Update test — remove assertion for bell button, add assertion that bell button is absent**

In `test/components/header/component_test.rb`, replace the test `"renders notification bell button"` (lines 100–105) with a test that verifies these buttons do NOT exist:

```ruby
test "does not render notification or user menu buttons" do
  render_inline(Header::Component.new)

  assert_no_selector "button[aria-label='알림']"
  assert_no_selector "button[aria-label='사용자 메뉴']"
end
```

Also update `"renders buttons with correct styling"` (lines 107–113) — this test asserts generic button styles that may match the remaining hamburger/dark-mode buttons. Replace with:

```ruby
test "renders only hamburger and dark mode buttons" do
  render_inline(Header::Component.new)

  # hamburger + dark-mode toggle = 2 buttons in the header
  assert_selector "button[aria-label='메뉴 열기']"
  assert_selector "button[aria-label='다크 모드 전환']"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/header/component_test.rb`

Expected: FAIL — `"does not render notification or user menu buttons"` fails because the buttons still exist in the template.

- [ ] **Step 3: Remove buttons from template**

In `app/components/header/component.html.erb`, delete lines 23–29 (the 알림 button and 사용자 메뉴 button). Keep line 21 (`<span id="analysis_indicator">`). The right side div should become:

```erb
  <div class="flex items-center gap-1">
    <div data-controller="dark-mode">
      <button type="button" class="<%= BUTTON_CLASSES %>" data-action="dark-mode#toggle" aria-label="다크 모드 전환">
        <span data-dark-mode-target="sunIcon"><%= sun_icon %></span>
        <span data-dark-mode-target="moonIcon" class="hidden"><%= moon_icon %></span>
      </button>
    </div>

    <span id="analysis_indicator"></span>
  </div>
```

- [ ] **Step 4: Remove unused helper methods from component.rb**

In `app/components/header/component.rb`, delete the `bell_icon` method (lines 42–48) and the `user_icon` method (lines 51–57). They are no longer called.

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/components/header/component_test.rb`

Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
git add app/components/header/component.html.erb app/components/header/component.rb test/components/header/component_test.rb
git commit -m "fix(header): remove unimplemented notification and user menu buttons"
```

---

### Task 2: Defensive fix for dark mode toggle navigation bug

**Files:**
- Modify: `app/javascript/controllers/dark_mode_controller.js:10-15`

- [ ] **Step 1: Apply fix — add event parameter and preventDefault**

In `app/javascript/controllers/dark_mode_controller.js`, change the `toggle` method from:

```javascript
toggle() {
  const isDark = document.documentElement.classList.contains("dark")
  this.setDarkMode(!isDark)
  localStorage.setItem("dark-mode", !isDark)
  this.updateIcons()
}
```

to:

```javascript
toggle(event) {
  event.preventDefault()
  event.stopPropagation()
  const isDark = document.documentElement.classList.contains("dark")
  this.setDarkMode(!isDark)
  localStorage.setItem("dark-mode", !isDark)
  this.updateIcons()
}
```

- [ ] **Step 2: Run full test suite to verify no regressions**

Run: `bin/rails test`

Expected: ALL PASS (no existing JS unit tests for this controller; regressions would appear in integration tests)

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/dark_mode_controller.js
git commit -m "fix(dark-mode): add preventDefault to stop Turbo navigation on toggle"
```

---

### Task 3: Unify app title to Korean

**Files:**
- Modify: `app/components/header/component.rb:8`
- Modify: `test/components/header/component_test.rb:15-33`

- [ ] **Step 1: Update tests — change expected title text**

In `test/components/header/component_test.rb`, update these tests:

Replace `"renders app name"` (lines 15–19):

```ruby
test "renders app name in Korean" do
  render_inline(Header::Component.new)

  assert_text "부동산 경매 도우미"
end
```

Replace `"renders app name with correct classes"` (lines 27–33):

```ruby
test "renders app name with correct classes" do
  render_inline(Header::Component.new)

  assert_selector "span.font-bold", text: "부동산 경매 도우미"
  assert_selector "span[class*='text-lg']"
  assert_selector "span[class*='text-white']"
end
```

Keep `"renders custom app name"` (lines 21–25) unchanged — it tests the override still works.

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/header/component_test.rb`

Expected: FAIL — `"renders app name in Korean"` fails because the default is still "Real Estate Auction".

- [ ] **Step 3: Change default app name**

In `app/components/header/component.rb` line 8, change:

```ruby
def initialize(app_name: "Real Estate Auction", page_title: nil)
```

to:

```ruby
def initialize(app_name: "부동산 경매 도우미", page_title: nil)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/header/component_test.rb`

Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add app/components/header/component.rb test/components/header/component_test.rb
git commit -m "fix(header): change app title from English to Korean"
```

---

### Task 4: Case number form client-side validation

**Files:**
- Modify: `app/views/properties/index.html.erb:54,71`
- Modify: `app/javascript/controllers/criteria_search_controller.js:4-8,54-65`

- [ ] **Step 1: Add inline error element and required attribute to the form**

In `app/views/properties/index.html.erb`, make two changes:

**Change 1:** Add `required: true` to the text_field on line 54:

```erb
<%= f.text_field :case_number,
    placeholder: "예: 2026타경1234",
    required: true,
    data: { criteria_search_target: "caseInput" },
    class: "flex-1 min-w-0 h-10 rounded-md border px-3 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100" %>
```

**Change 2:** Add an inline error element after the closing `<% end %>` of the form (after line 69) and before the helper text `<p>` tag on line 71. Insert this between them:

```erb
<p class="hidden text-sm text-red-500 dark:text-red-400 mt-1" data-criteria-search-target="caseError">사건번호를 입력해주세요</p>
```

The helper text paragraph (the one with "법원을 선택하면 빠르게 검색됩니다") stays as-is below it.

- [ ] **Step 2: Add caseError target and validation logic to Stimulus controller**

In `app/javascript/controllers/criteria_search_controller.js`:

**Change 1:** Add `"caseError"` to the static targets array (line 7):

```javascript
static targets = [
  "submitButton", "buttonText", "buttonSpinner",
  "caseInput", "addButton", "addButtonText", "addButtonSpinner",
  "caseError"
]
```

**Change 2:** Replace the `submitCaseNumber()` method (lines 54–65) with:

```javascript
// Case number form submit — validate then use readOnly so value is submitted
submitCaseNumber(event) {
  if (this.hasCaseErrorTarget) {
    this.caseErrorTarget.classList.add("hidden")
  }

  if (this.hasCaseInputTarget && this.caseInputTarget.value.trim() === "") {
    event.preventDefault()
    if (this.hasCaseErrorTarget) {
      this.caseErrorTarget.classList.remove("hidden")
    }
    return
  }

  if (this.hasCaseInputTarget) this.caseInputTarget.readOnly = true
  if (this.hasSubmitButtonTarget) {
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
  }
  if (this.hasAddButtonTarget) {
    this.addButtonTarget.disabled = true
    this.addButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
  }
  this.showSpinner("addButtonText", "addButtonSpinner")
}
```

- [ ] **Step 3: Clear error on input change**

Add a new method in `criteria_search_controller.js` after the `submitCaseNumber` method:

```javascript
clearCaseError() {
  if (this.hasCaseErrorTarget) {
    this.caseErrorTarget.classList.add("hidden")
  }
}
```

Then in `app/views/properties/index.html.erb`, add an `input` action to the text_field so the error clears when the user types. Update the text_field data attribute:

```erb
<%= f.text_field :case_number,
    placeholder: "예: 2026타경1234",
    required: true,
    data: { criteria_search_target: "caseInput", action: "input->criteria-search#clearCaseError" },
    class: "flex-1 min-w-0 h-10 rounded-md border px-3 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100" %>
```

- [ ] **Step 4: Run existing controller tests to verify no regressions**

Run: `bin/rails test test/controllers/properties_controller_test.rb`

Expected: ALL PASS (server-side validation logic is unchanged)

- [ ] **Step 5: Commit**

```bash
git add app/views/properties/index.html.erb app/javascript/controllers/criteria_search_controller.js
git commit -m "fix(properties): add client-side validation for empty case number input"
```

---

### Task 5: Fix eviction simulator "내 물건" mode Turbo error

**Files:**
- Modify: `config/routes.rb:65-70`
- Modify: `app/controllers/eviction_guide/simulations_controller.rb:3-27,59-63`
- Modify: `test/controllers/eviction_guide/simulations_controller_test.rb`

- [ ] **Step 1: Write failing test for create with property_id redirecting**

In `test/controllers/eviction_guide/simulations_controller_test.rb`, update the existing `"create with property_id creates persisted simulation"` test (lines 4–12) to also assert redirect:

```ruby
test "create with property_id creates simulation and redirects to prefill" do
  property = properties(:safe_apartment)
  assert_difference "EvictionSimulation.count", 1 do
    post eviction_guide_simulation_url, params: { property_id: property.id }
  end
  sim = EvictionSimulation.last
  assert_equal property.id, sim.property_id
  assert_nil sim.session_id
  assert_response :redirect
  assert_redirected_to eviction_guide_simulator_prefill_path
end
```

- [ ] **Step 2: Write test for the new prefill GET action**

Add a new test in the same file:

```ruby
test "prefill loads simulation from session and renders" do
  property = properties(:safe_apartment)
  # Create simulation via the create action to set session
  post eviction_guide_simulation_url, params: { property_id: property.id }
  assert_response :redirect

  get eviction_guide_simulator_prefill_path
  assert_response :success
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/controllers/eviction_guide/simulations_controller_test.rb`

Expected: FAIL — `"create with property_id"` test fails because it currently renders (200) instead of redirecting. `"prefill loads simulation"` fails because route does not exist.

- [ ] **Step 4: Add prefill route**

In `config/routes.rb`, inside the `namespace :eviction_guide` block (line 65–70), add the new GET route after line 66:

```ruby
namespace :eviction_guide do
  resource :simulation, only: [ :create, :update, :show ]
  get "simulator/prefill", to: "simulations#prefill", as: :simulator_prefill
  get "simulator/question/:code", to: "simulator#question", as: :simulator_question
  get "steps/:code", to: "steps#show", as: :step_detail
  get "branches/:code", to: "branches#show", as: :branch_detail
end
```

- [ ] **Step 5: Update create action to redirect instead of render**

In `app/controllers/eviction_guide/simulations_controller.rb`, replace lines 20–26:

```ruby
if @simulation.property_linked?
  @property = @simulation.property
  @prefill_data = EvictionGuide::F02DataExtractor.call(@property)
  render "eviction_guide/simulator/prefill"
else
  redirect_to eviction_guide_simulator_question_path(code: "Q1")
end
```

with:

```ruby
if @simulation.property_linked?
  redirect_to eviction_guide_simulator_prefill_path
else
  redirect_to eviction_guide_simulator_question_path(code: "Q1")
end
```

- [ ] **Step 6: Add prefill GET action**

In the same controller, add a new public method after `show` (before the `private` keyword on line 59):

```ruby
def prefill
  @simulation = find_simulation
  return redirect_to eviction_guide_simulator_path unless @simulation&.property_linked?

  @property = @simulation.property
  @prefill_data = EvictionGuide::F02DataExtractor.call(@property)
  render "eviction_guide/simulator/prefill"
end
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bin/rails test test/controllers/eviction_guide/simulations_controller_test.rb`

Expected: ALL PASS

- [ ] **Step 8: Run full test suite for regressions**

Run: `bin/rails test`

Expected: ALL PASS

- [ ] **Step 9: Commit**

```bash
git add config/routes.rb app/controllers/eviction_guide/simulations_controller.rb test/controllers/eviction_guide/simulations_controller_test.rb
git commit -m "fix(simulator): redirect to prefill page instead of render for Turbo compatibility"
```

---

### Task 6: Investigate and fix console 404 for /onboarding/step1

**Files:**
- Possibly modify: `config/routes.rb:4-12`

- [ ] **Step 1: Reproduce with Playwright**

Navigate to `http://localhost:3000/settings/budget` using Playwright MCP. After the page loads, check console messages with `browser_console_messages` (level: "error"). Look for any 404 referencing `/onboarding/step1`.

- [ ] **Step 2a: If reproducible — add a catch-all GET route**

In `config/routes.rb`, inside the `resource :onboarding` collection block (lines 4–12), add a GET route for step1 that redirects:

```ruby
resource :onboarding, only: [] do
  collection do
    get "/", action: :step1, as: :start
    get :step1, action: :step1
    post :step1, action: :create_step1
    post :step2, action: :create_step2
    post :step3, action: :create_step3
    get :complete
  end
end
```

The `get :step1` will match `GET /onboarding/step1` and invoke the `step1` action, which already redirects to `/settings/budget` when onboarding is completed (via `redirect_if_completed` before_action).

Run: `bin/rails test`

Expected: ALL PASS

Commit:

```bash
git add config/routes.rb
git commit -m "fix(routes): add GET /onboarding/step1 to prevent 404 from Turbo prefetch"
```

- [ ] **Step 2b: If NOT reproducible — skip**

Document as E2E-environment-only artifact. No code change needed.

---

### Task 7: E2E re-verification

**Files:**
- Create screenshots in: `docs/screenshots/`

This task uses Playwright MCP to verify all fixes from Tasks 1–6.

- [ ] **Step 1: Verify header cleanup (Task 1)**

Navigate to `http://localhost:3000/properties`. Take a snapshot. Verify:
- No button with `aria-label="알림"` exists
- No button with `aria-label="사용자 메뉴"` exists
- Dark mode toggle button exists
- `analysis_indicator` span exists

Take screenshot: `docs/screenshots/verify-t1-header-cleanup.png`

- [ ] **Step 2: Verify dark mode toggle (Task 2)**

On `/properties`, click the dark mode toggle button. Verify:
- Page URL is still `/properties` (no navigation occurred)
- `document.documentElement` has class `dark` (or doesn't if it was already dark)

Take screenshot: `docs/screenshots/verify-t2-darkmode-no-nav.png`

- [ ] **Step 3: Verify Korean app title (Task 3)**

On any page, verify the header contains "부동산 경매 도우미" instead of "Real Estate Auction".

Take screenshot: `docs/screenshots/verify-t3-korean-title.png`

- [ ] **Step 4: Verify case number validation (Task 4)**

On `/properties`:
1. Click the "추가" button with empty input. Verify the inline error message "사건번호를 입력해주세요" appears. Screenshot: `docs/screenshots/verify-t4-empty-validation.png`
2. Type any character in the input. Verify the error message disappears.
3. Clear the input, type a valid-format case number, click "추가". Verify form submits (no inline error).

- [ ] **Step 5: Verify simulator prefill (Task 5)**

Navigate to `/eviction_guide/simulator`. Select a property for "내 물건으로 시뮬레이션". Click "확인 완료 → 시뮬레이션 시작". Verify:
- No Turbo error
- Prefill page loads (URL contains `/eviction_guide/simulator/prefill`)
- Page shows prefill data correctly

Take screenshot: `docs/screenshots/verify-t5-simulator-prefill.png`

- [ ] **Step 6: Verify no console 404 (Task 6)**

Navigate to `/settings/budget`. Check `browser_console_messages` with level "error". Verify no 404 for `/onboarding/step1`.

Take screenshot: `docs/screenshots/verify-t6-no-console-404.png`

- [ ] **Step 7: Commit E2E report update**

Update `docs/e2e-test-report.md` with a new Run 8 section documenting the re-verification results.

```bash
git add docs/screenshots/ docs/e2e-test-report.md
git commit -m "test(e2e): verify all bugfix and polish changes from Run 7 audit"
```
