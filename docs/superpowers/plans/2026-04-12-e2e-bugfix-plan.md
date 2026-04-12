# E2E Test Bugfix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all Critical (P0) and High (P1) bugs discovered during E2E testing.

**Architecture:** 8 independent bug fixes across models, controllers, components, and static pages. Each task is self-contained — no cross-task dependencies.

**Tech Stack:** Rails 8.1, Ruby 3.4.8, Minitest, ViewComponent, TailwindCSS, Heroicons

---

## File Map

| Task | Files | Action |
|------|-------|--------|
| T1 | `app/components/report_summary_component.rb` | Modify: fix `format_price` calls |
| T2 | `app/models/budget_setting.rb` | Modify: add reserve field validations |
| T2 | `app/controllers/settings/budgets_controller.rb` | Modify: validate before calculate |
| T3 | `app/controllers/settings/budget_snapshots_controller.rb` | Modify: guard `params[:ids]` |
| T4 | `app/views/analyses/new.html.erb` | Modify: fix manual tab property_id handling |
| T4 | `app/controllers/analyses_controller.rb` | Modify: validate property existence |
| T5 | `app/components/snapshot_card_component.rb` | Modify: use 만원 formatting |
| T6 | `public/404.html`, `public/500.html` | Rewrite: Korean error pages |
| T7 | `app/components/header/component.html.erb` | Modify: add aria-labels |
| T8 | `app/components/sidebar/component.html.erb` | Modify: add 준비중 indicator |

---

### Task 1: Fix currency formatting bug (35700억원 → 3억 5,700만원)

**Root cause:** `ReportSummaryComponent#format_price` expects 만원 input, but `@property.appraisal_price` and `@property.min_bid_price` are stored in 원. The component should use `ApplicationHelper#format_price_won` which handles 원→만원 conversion.

**Files:**
- Modify: `app/components/report_summary_component.rb:41-51`
- Modify: `app/components/report_summary_component.html.erb:19,21`
- Test: `test/components/report_summary_component_test.rb`

- [ ] **Step 1: Write a failing test**

```ruby
# test/components/report_summary_component_test.rb
test "formats appraisal_price correctly from won to eok/manwon" do
  property = properties(:with_report)
  # appraisal_price is stored in 원 (e.g., 357_000_000 = 3억 5,700만원)
  property.update!(appraisal_price: 357_000_000, min_bid_price: 285_600_000)
  report = property.rights_report

  component = ReportSummaryComponent.new(property: property, report: report)
  rendered = render_inline(component)

  assert_text_match = rendered.text
  assert_includes assert_text_match, "3억 5,700만원"
  assert_includes assert_text_match, "2억 8,560만원"
  assert_no_text "35700억"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/report_summary_component_test.rb -v`
Expected: FAIL — output shows "35700억원" instead of "3억 5,700만원"

- [ ] **Step 3: Fix by replacing custom format_price with ApplicationHelper#format_price_won**

In `app/components/report_summary_component.rb`, replace the `format_price` method:

```ruby
def format_price(price_in_won)
  helpers.format_price_won(price_in_won)
end
```

This delegates to `ApplicationHelper#format_price_won` which correctly divides by 10,000 before formatting.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/report_summary_component_test.rb -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/components/report_summary_component.rb test/components/report_summary_component_test.rb
git commit -m "fix: correct currency unit conversion in report summary (원→만원)"
```

---

### Task 2: Add negative budget validation

**Root cause:** `BudgetSetting` validates `available_cash > 0` but reserve fields (`repair_cost`, `acquisition_tax`, etc.) have no numericality validation. Also, `BudgetCalculationService.call` runs before `@setting.save` validates, so negative values reach the calculation.

**Files:**
- Modify: `app/models/budget_setting.rb:7-8`
- Modify: `app/controllers/settings/budgets_controller.rb:9-44`
- Test: `test/models/budget_setting_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/models/budget_setting_test.rb
test "rejects negative available_cash" do
  setting = budget_settings(:default)
  setting.available_cash = -5000
  assert_not setting.valid?
  assert_includes setting.errors[:available_cash], "must be greater than 0"
end

test "rejects negative reserve fields" do
  setting = budget_settings(:default)
  BudgetSetting::RESERVE_FIELDS.each do |field|
    setting.send(:"#{field}=", -100)
  end
  assert_not setting.valid?
  BudgetSetting::RESERVE_FIELDS.each do |field|
    assert setting.errors[field].any?, "Expected error on #{field}"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/budget_setting_test.rb -v`
Expected: First test may pass (existing validation), second test FAIL (no reserve validation)

- [ ] **Step 3: Add numericality validations for reserve fields**

In `app/models/budget_setting.rb`, after the existing validations (around line 8), add:

```ruby
RESERVE_FIELDS.each do |field|
  validates field, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
```

- [ ] **Step 4: Ensure controller validates before calculating**

In `app/controllers/settings/budgets_controller.rb`, inside `update` action, move `@setting.assign_attributes(budget_params)` before the calculation, then check validity:

```ruby
def update
  @setting = current_user.budget_setting
  @setting.assign_attributes(budget_params)

  unless @setting.valid?
    load_show_data
    render :show, status: :unprocessable_entity
    return
  end

  result = BudgetCalculationService.call(setting: @setting)
  # ... rest of the method
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/models/budget_setting_test.rb -v`
Expected: ALL PASS

- [ ] **Step 6: Commit**

```bash
git add app/models/budget_setting.rb app/controllers/settings/budgets_controller.rb test/models/budget_setting_test.rb
git commit -m "fix: add numericality validation for budget reserve fields"
```

---

### Task 3: Fix snapshot compare crash (500 error)

**Root cause:** `budget_snapshots_controller#compare` reads `params[:ids]` directly. When accessed with `?base_id=X&compare_id=Y` or no params, `params[:ids]` is nil, causing `NoMethodError` on `nil[0]`.

**Files:**
- Modify: `app/controllers/settings/budget_snapshots_controller.rb:11-16`
- Test: `test/controllers/settings/budget_snapshots_controller_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
# test/controllers/settings/budget_snapshots_controller_test.rb
test "compare with missing ids redirects with error" do
  get compare_settings_budget_snapshots_path
  assert_redirected_to settings_budget_snapshots_path
  follow_redirect!
  assert_response :success
end

test "compare with invalid ids redirects with error" do
  get compare_settings_budget_snapshots_path, params: { ids: ["999998", "999999"] }
  assert_redirected_to settings_budget_snapshots_path
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/settings/budget_snapshots_controller_test.rb -v`
Expected: FAIL with NoMethodError or ActiveRecord::RecordNotFound

- [ ] **Step 3: Add guard clause to compare action**

In `app/controllers/settings/budget_snapshots_controller.rb`, replace the compare action:

```ruby
def compare
  ids = params[:ids]
  unless ids.is_a?(Array) && ids.size >= 2
    redirect_to settings_budget_snapshots_path, alert: "비교할 스냅샷 2개를 선택해주세요."
    return
  end

  @snapshot_a = current_user.budget_snapshots.find(ids[0])
  @snapshot_b = current_user.budget_snapshots.find(ids[1])
  @diff = BudgetSnapshotService.compare(snapshot_a: @snapshot_a, snapshot_b: @snapshot_b)
rescue ActiveRecord::RecordNotFound
  redirect_to settings_budget_snapshots_path, alert: "선택한 스냅샷을 찾을 수 없습니다."
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/settings/budget_snapshots_controller_test.rb -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/settings/budget_snapshots_controller.rb test/controllers/settings/budget_snapshots_controller_test.rb
git commit -m "fix: guard snapshot compare action against missing/invalid params"
```

---

### Task 4: Fix manual analysis tab 404 error

**Root cause:** When `/analyses/new` is accessed without a valid `property_id`, `@property` is nil (from `find_by`). The manual analysis form's submit action (`submitManual` in the Stimulus controller) likely constructs a URL using a property ID that doesn't exist. We need to ensure the controller validates property existence when the manual form is submitted.

**Files:**
- Modify: `app/controllers/analyses_controller.rb`
- Modify: `app/views/analyses/new.html.erb` (if needed)
- Test: `test/controllers/analyses_controller_test.rb`

- [ ] **Step 1: Investigate the exact Stimulus controller and form action**

Read `app/javascript/controllers/analysis_tabs_controller.js` to find how `submitManual` constructs the URL. Also check `app/views/analyses/_manual_form.html.erb` for the form's action URL.

- [ ] **Step 2: Write a failing test**

```ruby
# test/controllers/analyses_controller_test.rb
test "new page with non-existent property_id renders without error" do
  get new_analysis_path, params: { property_id: 99999 }
  assert_response :success
end

test "manual analysis submit with invalid property handles gracefully" do
  post analyses_path, params: { analysis: { content: "{}" }, property_id: 99999 }
  assert_response :redirect  # or :unprocessable_entity depending on flow
end
```

- [ ] **Step 3: Add validation in controller**

In `app/controllers/analyses_controller.rb`, add property existence validation for the manual submission flow. If `property_id` is given but doesn't exist, redirect with an error flash:

```ruby
def new
  @property = Property.find_by(id: params[:property_id])
  if params[:property_id].present? && @property.nil?
    redirect_to new_analysis_path, alert: "해당 매물을 찾을 수 없습니다."
    return
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/controllers/analyses_controller_test.rb -v`
Expected: ALL PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/analyses_controller.rb test/controllers/analyses_controller_test.rb
git commit -m "fix: validate property existence in analyses controller"
```

---

### Task 5: Fix snapshot card currency formatting

**Root cause:** `SnapshotCardComponent#formatted_amount` uses `number_to_delimited(@max_bid_amount)` which outputs raw numbers like "22,700". Need to use 만원/억 formatting for Korean readability.

**Files:**
- Modify: `app/components/snapshot_card_component.rb:25-27`
- Modify: `app/components/snapshot_card_component.html.erb:10-12`
- Test: `test/components/snapshot_card_component_test.rb`

- [ ] **Step 1: Write a failing test**

```ruby
# test/components/snapshot_card_component_test.rb
test "formats max_bid_amount in Korean currency units" do
  snapshot = budget_snapshots(:default)
  snapshot.update!(max_bid_amount: 357_000_000)

  component = SnapshotCardComponent.new(snapshot: snapshot)
  rendered = render_inline(component)

  # Should show "3억 5,700만원" not "357,000,000원"
  assert_includes rendered.text, "3억"
  assert_includes rendered.text, "5,700만원"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/snapshot_card_component_test.rb -v`
Expected: FAIL — shows "357,000,000원"

- [ ] **Step 3: Use ApplicationHelper#format_price_won for formatting**

In `app/components/snapshot_card_component.rb`, replace `formatted_amount`:

```ruby
def formatted_amount
  helpers.format_price_won(@max_bid_amount)
end
```

In `app/components/snapshot_card_component.html.erb`, remove the hardcoded "원" suffix (line 11):

```erb
<p class="text-lg font-bold text-slate-900 dark:text-slate-100 tabular-nums mb-3">
  <%= formatted_amount %>
</p>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/snapshot_card_component_test.rb -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/components/snapshot_card_component.rb app/components/snapshot_card_component.html.erb test/components/snapshot_card_component_test.rb
git commit -m "fix: format snapshot card amounts in Korean currency units"
```

---

### Task 6: Create Korean custom error pages

**Root cause:** `public/404.html` and `public/500.html` are default Rails English pages.

**Files:**
- Rewrite: `public/404.html`
- Rewrite: `public/500.html`

- [ ] **Step 1: Rewrite 404.html**

Replace `public/404.html` with a Korean-language page matching the app's design system:

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>페이지를 찾을 수 없습니다</title>
  <style>
    body {
      font-family: Pretendard, -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
      background-color: #f8fafc;
      color: #0f172a;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      text-align: center;
    }
    .container { max-width: 480px; padding: 2rem; }
    h1 { font-size: 4rem; font-weight: 700; color: #2563eb; margin: 0; }
    h2 { font-size: 1.25rem; font-weight: 600; color: #334155; margin: 1rem 0 0.5rem; }
    p { font-size: 1rem; color: #64748b; line-height: 1.6; }
    a {
      display: inline-block;
      margin-top: 1.5rem;
      padding: 0.625rem 1.5rem;
      background-color: #2563eb;
      color: #fff;
      border-radius: 0.375rem;
      text-decoration: none;
      font-weight: 500;
      font-size: 0.875rem;
    }
    a:hover { background-color: #1d4ed8; }
  </style>
</head>
<body>
  <div class="container">
    <h1>404</h1>
    <h2>페이지를 찾을 수 없습니다</h2>
    <p>요청하신 페이지가 존재하지 않거나 이동되었습니다.</p>
    <a href="/">홈으로 돌아가기</a>
  </div>
</body>
</html>
```

- [ ] **Step 2: Rewrite 500.html**

Replace `public/500.html`:

```html
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>서버 오류</title>
  <style>
    body {
      font-family: Pretendard, -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
      background-color: #f8fafc;
      color: #0f172a;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      text-align: center;
    }
    .container { max-width: 480px; padding: 2rem; }
    h1 { font-size: 4rem; font-weight: 700; color: #dc2626; margin: 0; }
    h2 { font-size: 1.25rem; font-weight: 600; color: #334155; margin: 1rem 0 0.5rem; }
    p { font-size: 1rem; color: #64748b; line-height: 1.6; }
    a {
      display: inline-block;
      margin-top: 1.5rem;
      padding: 0.625rem 1.5rem;
      background-color: #2563eb;
      color: #fff;
      border-radius: 0.375rem;
      text-decoration: none;
      font-weight: 500;
      font-size: 0.875rem;
    }
    a:hover { background-color: #1d4ed8; }
  </style>
</head>
<body>
  <div class="container">
    <h1>500</h1>
    <h2>서버 오류가 발생했습니다</h2>
    <p>일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.</p>
    <a href="/">홈으로 돌아가기</a>
  </div>
</body>
</html>
```

- [ ] **Step 3: Verify pages render correctly**

Open `public/404.html` and `public/500.html` in browser to confirm styling and Korean text.

- [ ] **Step 4: Commit**

```bash
git add public/404.html public/500.html
git commit -m "feat: add Korean custom 404 and 500 error pages"
```

---

### Task 7: Add aria-labels to header icon buttons

**Root cause:** Header icon buttons (hamburger, dark mode toggle, bell, user) have no `aria-label` attributes. Screen readers can't identify them.

**Files:**
- Modify: `app/components/header/component.html.erb:3,14-19,23-25,27-29`

- [ ] **Step 1: Add aria-labels to all icon buttons**

In `app/components/header/component.html.erb`:

- Hamburger button (line 3): add `aria-label="메뉴 열기"`
- Dark mode toggle (around line 14): add `aria-label="다크 모드 전환"`
- Bell button (around line 23): add `aria-label="알림"`
- User button (around line 27): add `aria-label="사용자 메뉴"`

- [ ] **Step 2: Verify in browser**

Inspect each button in browser dev tools → verify `aria-label` is present.

- [ ] **Step 3: Commit**

```bash
git add app/components/header/component.html.erb
git commit -m "fix: add aria-labels to header icon buttons for accessibility"
```

---

### Task 8: Add "준비중" indicator to disabled sidebar items

**Root cause:** Disabled sidebar items render as `<button disabled>` with `title` matching the label name. No visual indicator tells users the feature is coming soon.

**Files:**
- Modify: `app/components/sidebar/component.html.erb:25-33`

- [ ] **Step 1: Add "준비중" tooltip and visual badge**

In `app/components/sidebar/component.html.erb`, update the disabled button block (lines 26-32):

```erb
<button type="button" disabled
        class="<%= item_classes(item) %> w-full opacity-50"
        data-sidebar-item
        title="준비중">
  <%= menu_icon(item.icon) %>
  <span class="hidden lg:inline" data-sidebar-label>
    <%= item.label %>
    <span class="ml-1 text-sm font-medium text-slate-400 dark:text-slate-500">(준비중)</span>
  </span>
</button>
```

Changes:
- `title` changed from label name to "준비중"
- Added `opacity-50` for visual de-emphasis
- Added "(준비중)" text label visible in expanded sidebar

- [ ] **Step 2: Verify in browser**

Check sidebar in expanded and collapsed states. Disabled items should show "(준비중)" when expanded and tooltip on hover when collapsed.

- [ ] **Step 3: Commit**

```bash
git add app/components/sidebar/component.html.erb
git commit -m "feat: add coming-soon indicator to disabled sidebar items"
```
