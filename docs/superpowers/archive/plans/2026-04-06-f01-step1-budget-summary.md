# F01 Step1 Budget Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display previous budget calculation results at the top of the onboarding step1 screen via a new BudgetSummaryComponent.

**Architecture:** A single ViewComponent (`BudgetSummaryComponent`) renders a 4-column stat grid with two visual states (calculated vs uncalculated). It receives the existing `@setting` from the controller — no new queries or controller changes needed.

**Tech Stack:** ViewComponent, TailwindCSS, Minitest

**Spec:** `docs/superpowers/specs/2026-04-06-f01-step1-budget-summary-design.md`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `app/components/budget_summary_component.rb` | Component class — accepts `setting`, exposes `calculated?` helper and formatted values |
| Create | `app/components/budget_summary_component.html.erb` | Template — 4-column grid with conditional styling |
| Create | `test/components/budget_summary_component_test.rb` | Unit tests for both states, formatting, responsive classes |
| Modify | `app/views/onboardings/step1.html.erb` | Insert component render above WizardStepComponent |
| Modify | `test/controllers/onboardings_controller_test.rb` | Integration test — step1 renders summary component |

---

### Task 1: BudgetSummaryComponent — Unit Tests (RED)

**Files:**
- Create: `test/components/budget_summary_component_test.rb`

- [ ] **Step 1: Write failing tests for both component states**

```ruby
# frozen_string_literal: true

require "test_helper"

class BudgetSummaryComponentTest < ViewComponent::TestCase
  # --- Calculated state ---

  test "renders calculated state when max_bid_amount is present" do
    setting = budget_settings(:completed)

    render_inline(BudgetSummaryComponent.new(setting: setting))

    assert_selector "div[class*='bg-blue-50']"
    assert_selector "div[class*='border-blue-200']"
    assert_text "최대입찰가"
    assert_text "96,200만원"
  end

  test "renders all four metrics with calculated values" do
    setting = budget_settings(:completed)

    render_inline(BudgetSummaryComponent.new(setting: setting))

    assert_text "유용자금"
    assert_text "30,000만원"
    assert_text "예비비 합계"
    assert_text "1,140만원"
    assert_text "대출비율"
    assert_text "70%"
  end

  # --- Uncalculated state ---

  test "renders uncalculated state when setting is nil" do
    render_inline(BudgetSummaryComponent.new(setting: nil))

    assert_selector "div[class*='bg-slate-50']"
    assert_selector "div[class*='border-dashed']"
    assert_text "최대입찰가"
    # Em dash for empty values
    page_html = page.native.inner_html
    assert_includes page_html, "—"
  end

  test "renders uncalculated state when max_bid_amount is nil" do
    setting = BudgetSetting.new

    render_inline(BudgetSummaryComponent.new(setting: setting))

    assert_selector "div[class*='border-dashed']"
  end

  # --- Responsive grid ---

  test "renders responsive grid classes" do
    render_inline(BudgetSummaryComponent.new(setting: nil))

    assert_selector "div[class*='grid-cols-2']"
    assert_selector "div[class*='sm:grid-cols-4']"
  end
end
```

- [ ] **Step 2: Create the `:completed` budget_settings fixture**

The test references `budget_settings(:completed)`. Check if it already exists in `test/fixtures/budget_settings.yml`. If not, add:

```yaml
# Append to test/fixtures/budget_settings.yml
completed:
  user: guest
  available_cash: 30000
  property_type: apartment
  loan_policy: auction_bank_apartment
  loan_ratio: 0.7
  failed_auction_rounds: 2
  repair_cost: 500
  acquisition_tax: 360
  scrivener_fee: 80
  moving_cost: 150
  maintenance_fee: 50
  max_bid_amount: 96200
  searchable_appraisal_limit: 150312
  area_unit: pyeong
  area_range_min: 59
  area_range_max: 84
  completed_at: <%= Time.current %>
```

Note: `total_reserves` for this fixture = 500 + 360 + 80 + 150 + 50 = 1,140.

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/components/budget_summary_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant BudgetSummaryComponent`

- [ ] **Step 4: Commit**

```bash
git add test/components/budget_summary_component_test.rb test/fixtures/budget_settings.yml
git commit -m "test(f01): add failing tests for BudgetSummaryComponent"
```

---

### Task 2: BudgetSummaryComponent — Implementation (GREEN)

**Files:**
- Create: `app/components/budget_summary_component.rb`
- Create: `app/components/budget_summary_component.html.erb`

- [ ] **Step 1: Create the component class**

```ruby
# frozen_string_literal: true

class BudgetSummaryComponent < ViewComponent::Base
  include ActionView::Helpers::NumberHelper

  def initialize(setting: nil)
    @setting = setting
  end

  def calculated?
    @setting.present? && @setting.max_bid_amount.present?
  end

  def container_classes
    base = "grid grid-cols-2 sm:grid-cols-4 gap-3 rounded-lg p-4 mb-6 text-center"
    if calculated?
      "#{base} bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800"
    else
      "#{base} bg-slate-50 dark:bg-slate-800 border border-dashed border-slate-300 dark:border-slate-600"
    end
  end

  def max_bid_amount
    calculated? ? "#{number_with_delimiter(@setting.max_bid_amount)}만원" : "—"
  end

  def available_cash
    calculated? ? "#{number_with_delimiter(@setting.available_cash)}만원" : "—"
  end

  def total_reserves
    calculated? ? "#{number_with_delimiter(@setting.total_reserves)}만원" : "—"
  end

  def loan_ratio
    calculated? ? "#{(@setting.loan_ratio * 100).round}%" : "—"
  end

  def primary_value_classes
    if calculated?
      "text-base font-bold tabular-nums text-blue-700 dark:text-blue-300"
    else
      "text-base font-bold tabular-nums text-slate-300 dark:text-slate-600"
    end
  end

  def secondary_value_classes
    if calculated?
      "text-sm font-semibold tabular-nums text-slate-700 dark:text-slate-200"
    else
      "text-sm font-semibold tabular-nums text-slate-300 dark:text-slate-600"
    end
  end

  def label_classes
    if calculated?
      "text-xs text-slate-500 dark:text-slate-400"
    else
      "text-xs text-slate-400 dark:text-slate-500"
    end
  end
end
```

- [ ] **Step 2: Create the component template**

```erb
<%# app/components/budget_summary_component.html.erb %>
<div class="<%= container_classes %>">
  <div>
    <p class="<%= label_classes %>">최대입찰가</p>
    <p class="<%= primary_value_classes %>"><%= max_bid_amount %></p>
  </div>
  <div>
    <p class="<%= label_classes %>">유용자금</p>
    <p class="<%= secondary_value_classes %>"><%= available_cash %></p>
  </div>
  <div>
    <p class="<%= label_classes %>">예비비 합계</p>
    <p class="<%= secondary_value_classes %>"><%= total_reserves %></p>
  </div>
  <div>
    <p class="<%= label_classes %>">대출비율</p>
    <p class="<%= secondary_value_classes %>"><%= loan_ratio %></p>
  </div>
</div>
```

- [ ] **Step 3: Run tests to verify they pass**

Run: `bin/rails test test/components/budget_summary_component_test.rb`
Expected: all 5 tests PASS

- [ ] **Step 4: Commit**

```bash
git add app/components/budget_summary_component.rb app/components/budget_summary_component.html.erb
git commit -m "feat(f01): add BudgetSummaryComponent with calculated/uncalculated states"
```

---

### Task 3: Integrate into Step1 View

**Files:**
- Modify: `app/views/onboardings/step1.html.erb`

- [ ] **Step 1: Add component render to step1 view**

Insert `<%= render BudgetSummaryComponent.new(setting: @setting) %>` as the first child inside the `<turbo-frame>`, before the `WizardStepComponent` render.

The result should look like:

```erb
<turbo-frame id="onboarding_wizard">
  <%= render BudgetSummaryComponent.new(setting: @setting) %>
  <%= render WizardStepComponent.new(
    title: "투자 가능한 유용자금을 입력하��요",
    ...
```

- [ ] **Step 2: Run component tests to verify nothing broke**

Run: `bin/rails test test/components/budget_summary_component_test.rb`
Expected: all PASS

- [ ] **Step 3: Commit**

```bash
git add app/views/onboardings/step1.html.erb
git commit -m "feat(f01): render BudgetSummaryComponent on onboarding step1"
```

---

### Task 4: Integration Test

**Files:**
- Modify: `test/controllers/onboardings_controller_test.rb`

- [ ] **Step 1: Add integration tests for summary rendering**

Append these tests to `OnboardingsControllerTest`:

```ruby
test "GET step1 renders budget summary in uncalculated state for new user" do
  get start_onboarding_url
  assert_response :success
  # Summary grid is rendered with dashed border (uncalculated)
  assert_select "div[class*='border-dashed']"
  assert_select "div[class*='grid-cols-2']"
end

test "GET step1 renders budget summary with values for returning user" do
  # First complete onboarding to establish a calculated setting
  get start_onboarding_url
  guest = User.find_by(email: "guest@auction.local")
  apt = property_types(:apartment)
  policy = loan_policies(:auction_bank_apartment)

  BudgetSetting.create!(
    user: guest, available_cash: 30000, property_type: apt,
    loan_policy: policy, loan_ratio: 0.7, failed_auction_rounds: 0,
    repair_cost: 500, acquisition_tax: 360, scrivener_fee: 80,
    moving_cost: 150, maintenance_fee: 50,
    max_bid_amount: 96200, searchable_appraisal_limit: 96200,
    area_unit: "pyeong", completed_at: Time.current
  )

  get start_onboarding_url
  assert_response :success
  # Summary grid is rendered with solid border (calculated)
  assert_select "div[class*='bg-blue-50']"
  assert_select "div[class*='border-blue-200']"
end
```

- [ ] **Step 2: Run integration tests**

Run: `bin/rails test test/controllers/onboardings_controller_test.rb`
Expected: all tests PASS (existing + 2 new)

- [ ] **Step 3: Run full test suite**

Run: `bin/rails test`
Expected: all PASS, no regressions

- [ ] **Step 4: Commit**

```bash
git add test/controllers/onboardings_controller_test.rb
git commit -m "test(f01): add integration tests for budget summary on step1"
```

---

## Verification

After all tasks are complete:

1. `bin/rails test` — all tests pass
2. `bin/rubocop` — no style violations
3. `bin/dev` — start dev server, visit `/onboarding`:
   - **New user**: summary shows 4 metrics with `—` values, dashed gray border
   - **Returning user** (after completing wizard once): summary shows real values with blue background
   - **Mobile viewport**: grid collapses to 2x2
