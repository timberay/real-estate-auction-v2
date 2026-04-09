# Region Selector Dropdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an auto-saving region dropdown to onboarding step 1, budget settings, and properties index so users can select their target auction region.

**Architecture:** A lightweight Stimulus controller (`region-select`) sends a PATCH request on select change to a dedicated endpoint (`Settings::BudgetsController#update_region`) that updates only the `region` field. The same `<select>` markup is placed in three views, each wired to the same Stimulus controller and endpoint.

**Tech Stack:** Rails 8.1, Stimulus (pure JS), Turbo, TailwindCSS, Minitest

---

### Task 1: Route and Controller Action

**Files:**
- Modify: `config/routes.rb:14-16`
- Modify: `app/controllers/settings/budgets_controller.rb`
- Test: `test/controllers/settings/budgets_controller_test.rb`

- [ ] **Step 1: Write the failing test for update_region success**

Add to `test/controllers/settings/budgets_controller_test.rb`:

```ruby
test "PATCH update_region saves region and returns ok" do
  patch update_region_settings_budget_url, params: {
    budget_setting: { region: "서울특별시" }
  }
  assert_response :ok
  assert_equal "서울특별시", @setting.reload.region
end
```

- [ ] **Step 2: Write the failing test for update_region with invalid region**

Add to `test/controllers/settings/budgets_controller_test.rb`:

```ruby
test "PATCH update_region rejects invalid region" do
  patch update_region_settings_budget_url, params: {
    budget_setting: { region: "존재하지않는지역" }
  }
  assert_response :unprocessable_entity
  assert_nil @setting.reload.region
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/controllers/settings/budgets_controller_test.rb`
Expected: FAIL — `update_region_settings_budget_url` is undefined (no route).

- [ ] **Step 4: Add the route**

In `config/routes.rb`, change the budget resource block from:

```ruby
resource :budget, only: [ :show, :update ]
```

to:

```ruby
resource :budget, only: [ :show, :update ] do
  member do
    patch :update_region
  end
end
```

- [ ] **Step 5: Add the controller action**

In `app/controllers/settings/budgets_controller.rb`, add the `update_region` method after the `update` method:

```ruby
def update_region
  @setting = current_user.budget_setting
  if @setting.update(region: params.dig(:budget_setting, :region))
    head :ok
  else
    head :unprocessable_entity
  end
end
```

- [ ] **Step 6: Add `:region` to `budget_params`**

In `app/controllers/settings/budgets_controller.rb`, update `budget_params` to include `:region`:

```ruby
def budget_params
  params.expect(budget_setting: [
    :available_cash, :property_type_id, :area_category,
    :repair_cost, :acquisition_tax, :scrivener_fee,
    :moving_cost, :maintenance_fee, :loan_policy_id, :loan_ratio,
    :region
  ])
end
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bin/rails test test/controllers/settings/budgets_controller_test.rb`
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/settings/budgets_controller.rb test/controllers/settings/budgets_controller_test.rb
git commit -m "feat: add update_region endpoint for auto-saving region selection"
```

---

### Task 2: Onboarding Controller — Permit Region in Step 1

**Files:**
- Modify: `app/controllers/onboardings_controller.rb:92-94`
- Test: `test/controllers/onboardings_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Add to `test/controllers/onboardings_controller_test.rb`:

```ruby
test "POST step1 saves region along with available_cash" do
  get start_onboarding_url

  post step1_onboarding_url, params: {
    budget_setting: { available_cash: 30000, region: "서울특별시" }
  }
  assert_response :success

  user = User.find_by(email: "guest@auction.local")
  assert_equal "서울특별시", user.budget_setting.region
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/onboardings_controller_test.rb -n "test_POST_step1_saves_region_along_with_available_cash"`
Expected: FAIL — region is not permitted, so it is not saved.

- [ ] **Step 3: Add `:region` to `step1_params`**

In `app/controllers/onboardings_controller.rb`, change `step1_params` from:

```ruby
def step1_params
  params.expect(budget_setting: [ :available_cash ])
end
```

to:

```ruby
def step1_params
  params.expect(budget_setting: [ :available_cash, :region ])
end
```

- [ ] **Step 4: Update `create_step1` to assign region**

In `app/controllers/onboardings_controller.rb`, change `create_step1` from:

```ruby
def create_step1
  @setting.available_cash = step1_params[:available_cash]

  if @setting.save
    load_step2_data
    render :step2
  else
    render :step1, status: :unprocessable_entity
  end
end
```

to:

```ruby
def create_step1
  @setting.available_cash = step1_params[:available_cash]
  @setting.region = step1_params[:region]

  if @setting.save
    load_step2_data
    render :step2
  else
    render :step1, status: :unprocessable_entity
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/onboardings_controller_test.rb`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/onboardings_controller.rb test/controllers/onboardings_controller_test.rb
git commit -m "feat: permit region param in onboarding step 1"
```

---

### Task 3: Stimulus Controller — `region-select`

**Files:**
- Create: `app/javascript/controllers/region_select_controller.js`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/region_select_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }
  static targets = ["feedback"]

  connect() {
    this.previousValue = this.element.value
  }

  save() {
    const region = this.element.value
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": token,
        "Accept": "application/json"
      },
      body: JSON.stringify({ budget_setting: { region } })
    }).then(response => {
      if (response.ok) {
        this.previousValue = region
        this.showFeedback()
      } else {
        this.element.value = this.previousValue
      }
    }).catch(() => {
      this.element.value = this.previousValue
    })
  }

  showFeedback() {
    if (!this.hasFeedbackTarget) return

    this.feedbackTarget.textContent = "✓ 저장됨"
    this.feedbackTarget.classList.remove("opacity-0")
    this.feedbackTarget.classList.add("opacity-100")

    setTimeout(() => {
      this.feedbackTarget.classList.remove("opacity-100")
      this.feedbackTarget.classList.add("opacity-0")
    }, 1500)
  }
}
```

- [ ] **Step 2: Verify the controller is auto-registered**

This project uses importmap with Stimulus autoloading via `controllers/index.js`. Run:

```bash
bin/rails stimulus:manifest:update
```

Confirm `region_select_controller` appears in the manifest.

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/region_select_controller.js
git commit -m "feat: add region-select Stimulus controller for auto-save"
```

---

### Task 4: Onboarding Step 1 View — Add Region Dropdown

**Files:**
- Modify: `app/views/onboardings/step1.html.erb`

- [ ] **Step 1: Add the region select above the 유용자금 input**

In `app/views/onboardings/step1.html.erb`, insert a region select block between the error div and the 유용자금 div. The full file should become:

```erb
<turbo-frame id="onboarding_wizard">
  <%= render BudgetSummaryComponent.new(setting: @setting) %>
  <%= render WizardStepComponent.new(
    title: "투자 가능한 유용자금을 입력하세요",
    description: "유용자금이란 현재 투자에 사용할 수 있는 현금을 말합니다",
    current_step: 1,
    total_steps: 3
  ) do %>
    <%= form_with model: @setting, url: step1_onboarding_path, method: :post, data: { turbo_frame: "onboarding_wizard" } do |f| %>
      <% if @setting.errors[:available_cash].any? %>
        <div class="mb-4 p-3 bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 rounded-lg text-sm">
          <%= @setting.errors[:available_cash].join(", ") %>
        </div>
      <% end %>

      <div class="mb-6">
        <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">관심 지역</label>
        <div class="flex items-center gap-2">
          <%= f.select :region,
            options_for_select(BudgetSetting::REGIONS, @setting.effective_region),
            {},
            class: "flex-1 h-10 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500",
            data: { controller: "region-select", region_select_url_value: update_region_settings_budget_path, region_select_target: "select", action: "change->region-select#save" } %>
          <span class="text-sm text-slate-500 dark:text-slate-400 transition-opacity duration-300 opacity-0" data-region-select-target="feedback"></span>
        </div>
      </div>

      <div class="mb-6" data-controller="number-format" data-number-format-initial-value="<%= @setting.available_cash || 3000 %>">
        <label for="available_cash_display" class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">유용자금</label>
        <div class="flex items-center gap-2">
          <input type="text" id="available_cash_display"
            inputmode="numeric"
            class="flex-1 h-10 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
            placeholder="3,000"
            data-number-format-target="display"
            data-action="input->number-format#format blur->number-format#formatDisplay">
          <%= f.hidden_field :available_cash, data: { number_format_target: "hidden" } %>
          <span class="text-slate-600 dark:text-slate-400 font-medium whitespace-nowrap">만원</span>
          <%= render ButtonComponent.new(icon: "arrow-right", size: :md, type: "submit") { "다음" } %>
        </div>
      </div>
    <% end %>
  <% end %>
</turbo-frame>
```

- [ ] **Step 2: Verify manually in browser**

Run: `bin/dev`
Navigate to `/onboarding` — confirm the "관심 지역" dropdown appears above the 유용자금 input, defaults to "제주특별자치도", and changing it shows "✓ 저장됨" feedback.

- [ ] **Step 3: Commit**

```bash
git add app/views/onboardings/step1.html.erb
git commit -m "feat: add region dropdown to onboarding step 1"
```

---

### Task 5: Budget Settings View — Add Region Card

**Files:**
- Modify: `app/views/settings/budgets/show.html.erb`

- [ ] **Step 1: Add the region card above the 유용자금 card**

In `app/views/settings/budgets/show.html.erb`, insert a new region card section between the error block and the existing `<%# Section 1: Available Cash %>` comment. Add this block:

```erb
    <%# Section 0: Region %>
    <%= render CardComponent.new(title: "관심 지역", class: "mb-6") do %>
      <div class="flex items-center gap-2">
        <%= f.select :region,
          options_for_select(BudgetSetting::REGIONS, @setting.effective_region),
          {},
          class: "flex-1 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500",
          data: { controller: "region-select", region_select_url_value: update_region_settings_budget_path, region_select_target: "select", action: "change->region-select#save" } %>
        <span class="text-sm text-slate-500 dark:text-slate-400 transition-opacity duration-300 opacity-0" data-region-select-target="feedback"></span>
      </div>
    <% end %>
```

Insert this immediately before the line `<%# Section 1: Available Cash %>`.

- [ ] **Step 2: Verify manually in browser**

Run: `bin/dev`
Navigate to `/settings/budget` — confirm the "관심 지역" card appears as the first card, defaults to the saved region (or "제주특별자치도"), and auto-saves on change.

- [ ] **Step 3: Commit**

```bash
git add app/views/settings/budgets/show.html.erb
git commit -m "feat: add region dropdown card to budget settings page"
```

---

### Task 6: Properties Index — Add Region Dropdown

**Files:**
- Modify: `app/views/properties/index.html.erb`
- Modify: `app/controllers/properties_controller.rb`

- [ ] **Step 1: Load `@setting` in the properties controller**

In `app/controllers/properties_controller.rb`, inside the `index` action, add this line after the `@max_bid_amount` assignment (line 14):

```ruby
@setting = current_user.budget_setting
```

Note: `@max_bid_amount` is already derived from `budget_setting` on line 14 — `@setting` provides the full object for the region dropdown.

- [ ] **Step 2: Add region dropdown to the view**

In `app/views/properties/index.html.erb`, inside the `data-controller="criteria-search"` div (after `<div data-controller="criteria-search" class="max-w-md">`), insert a region select block before the `<label class="block text-sm font-medium...">사건번호로 물건 추가</label>` line:

```erb
    <div class="mb-4">
      <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">관심 지역</label>
      <div class="flex items-center gap-2">
        <select name="budget_setting[region]"
                class="flex-1 h-8 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
                data-controller="region-select"
                data-region-select-url-value="<%= update_region_settings_budget_path %>"
                data-action="change->region-select#save">
          <% BudgetSetting::REGIONS.each do |region| %>
            <option value="<%= region %>" <%= "selected" if region == @setting&.effective_region %>><%= region %></option>
          <% end %>
        </select>
        <span class="text-sm text-slate-500 dark:text-slate-400 transition-opacity duration-300 opacity-0" data-region-select-target="feedback"></span>
      </div>
    </div>
```

- [ ] **Step 3: Verify manually in browser**

Run: `bin/dev`
Navigate to `/properties` — confirm the "관심 지역" dropdown appears above the 사건번호 input, defaults to the saved region, and auto-saves on change.

- [ ] **Step 4: Commit**

```bash
git add app/views/properties/index.html.erb app/controllers/properties_controller.rb
git commit -m "feat: add region dropdown to properties index page"
```

---

### Task 7: Run Full Test Suite

**Files:**
- No new files

- [ ] **Step 1: Run all tests**

```bash
bin/rails test
```

Expected: All tests PASS, including previously existing tests.

- [ ] **Step 2: Run rubocop**

```bash
bin/rubocop
```

Expected: No new offenses. Fix any that appear.

- [ ] **Step 3: Commit any fixes**

If rubocop required fixes:

```bash
git add -A
git commit -m "style: fix rubocop offenses from region selector"
```
