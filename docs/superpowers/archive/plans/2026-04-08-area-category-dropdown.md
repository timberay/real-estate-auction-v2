# Area Category Dropdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace free-text area inputs with category-based dropdowns using standard Korean apartment size classifications.

**Architecture:** Remove unit toggle (평/㎡) and conversion logic entirely. Both min and max dropdowns show the same 5 category labels with 평 and ㎡ together. Min dropdown stores the category's lower ㎡ bound; max stores the upper bound. DB columns `area_range_min`/`area_range_max` remain integers in ㎡.

**Tech Stack:** Rails 8.1, Stimulus, Minitest

**Spec:** `docs/superpowers/specs/2026-04-08-area-category-dropdown-design.md`

---

### Task 1: Define Area Categories Constant in Model

**Files:**
- Modify: `app/models/budget_setting.rb`
- Test: `test/models/budget_setting_test.rb`

- [ ] **Step 1: Write failing test for AREA_CATEGORIES constant**

Add to `test/models/budget_setting_test.rb`:

```ruby
test "AREA_CATEGORIES has 5 categories with correct structure" do
  cats = BudgetSetting::AREA_CATEGORIES
  assert_equal 5, cats.length
  assert_equal :small, cats.first[:key]
  assert_equal 0, cats.first[:min_sqm]
  assert_equal 40, cats.first[:max_sqm]
  assert_equal :large, cats.last[:key]
  assert_equal 102, cats.last[:min_sqm]
  assert_equal 150, cats.last[:max_sqm]
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/budget_setting_test.rb -n "test_AREA_CATEGORIES_has_5_categories_with_correct_structure"`
Expected: NameError — `BudgetSetting::AREA_CATEGORIES`

- [ ] **Step 3: Implement AREA_CATEGORIES constant**

In `app/models/budget_setting.rb`, add after `RESERVE_FIELDS`:

```ruby
AREA_CATEGORIES = [
  { key: :small,      label: "소형 (10~15평 / ~40㎡)",          min_sqm: 0,   max_sqm: 40 },
  { key: :mid_small,  label: "중소형 (20~25평 / 40~60㎡)",      min_sqm: 40,  max_sqm: 60 },
  { key: :mid,        label: "중형 · 국평 (30~34평 / 60~85㎡)", min_sqm: 60,  max_sqm: 85 },
  { key: :mid_large,  label: "중대형 (38~42평 / 85~102㎡)",     min_sqm: 85,  max_sqm: 102 },
  { key: :large,      label: "대형 (45평~ / 102㎡~)",           min_sqm: 102, max_sqm: 150 }
].freeze
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/models/budget_setting_test.rb -n "test_AREA_CATEGORIES_has_5_categories_with_correct_structure"`
Expected: PASS

- [ ] **Step 5: Write failing test for dropdown options helpers**

Add to `test/models/budget_setting_test.rb`:

```ruby
test "area_min_options returns categories with min_sqm values" do
  options = BudgetSetting.area_min_options
  assert_equal 5, options.length
  assert_equal ["소형 (10~15평 / ~40㎡)", 0], options.first
  assert_equal ["대형 (45평~ / 102㎡~)", 102], options.last
end

test "area_max_options returns categories with max_sqm values" do
  options = BudgetSetting.area_max_options
  assert_equal 5, options.length
  assert_equal ["소형 (10~15평 / ~40㎡)", 40], options.first
  assert_equal ["대형 (45평~ / 102㎡~)", 150], options.last
end
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `bin/rails test test/models/budget_setting_test.rb -n "/area_.*_options/"`
Expected: NoMethodError

- [ ] **Step 7: Implement helper class methods**

In `app/models/budget_setting.rb`, add:

```ruby
def self.area_min_options
  AREA_CATEGORIES.map { |c| [c[:label], c[:min_sqm]] }
end

def self.area_max_options
  AREA_CATEGORIES.map { |c| [c[:label], c[:max_sqm]] }
end
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `bin/rails test test/models/budget_setting_test.rb -n "/area_.*_options/"`
Expected: PASS

- [ ] **Step 9: Write failing test for min≤max validation**

Add to `test/models/budget_setting_test.rb`:

```ruby
test "invalid when area_range_min exceeds area_range_max" do
  bs = BudgetSetting.new(
    user: users(:guest), available_cash: 30000,
    area_range_min: 85, area_range_max: 40,
    failed_auction_rounds: 0
  )
  assert_not bs.valid?
  assert_includes bs.errors[:area_range_min], "은(는) 면적 최대 이하여야 합니다"
end

test "valid when area_range_min equals area_range_max" do
  bs = BudgetSetting.new(
    user: users(:guest), available_cash: 30000,
    area_range_min: 60, area_range_max: 85,
    failed_auction_rounds: 0
  )
  assert bs.valid?
end
```

- [ ] **Step 10: Run tests to verify they fail**

Run: `bin/rails test test/models/budget_setting_test.rb -n "/area_range_min/"`
Expected: First test FAILS (no validation error), second may pass

- [ ] **Step 11: Implement validation**

In `app/models/budget_setting.rb`, add validation:

```ruby
validate :area_range_min_not_exceeding_max

private

def area_range_min_not_exceeding_max
  return unless area_range_min.present? && area_range_max.present?
  if area_range_min > area_range_max
    errors.add(:area_range_min, "은(는) 면적 최대 이하여야 합니다")
  end
end
```

- [ ] **Step 12: Run tests to verify they pass**

Run: `bin/rails test test/models/budget_setting_test.rb -n "/area_range_min/"`
Expected: PASS

- [ ] **Step 13: Commit**

```bash
git add app/models/budget_setting.rb test/models/budget_setting_test.rb
git commit -m "feat(model): add AREA_CATEGORIES constant, dropdown helpers, and min≤max validation"
```

---

### Task 2: Remove Unit Conversion Logic from Model

**Files:**
- Modify: `app/models/budget_setting.rb`
- Modify: `test/models/budget_setting_test.rb`

- [ ] **Step 1: Remove old area_unit validation and conversion methods**

In `app/models/budget_setting.rb`:

1. Remove `validates :area_unit, inclusion: { in: %w[pyeong sqm] }`
2. Remove `SQM_PER_PYEONG = 3.305785`
3. Remove `convert_area_to_sqm!` method (lines 27-32)
4. Remove `display_area_min` method (lines 35-39)
5. Remove `display_area_max` method (lines 41-45)

- [ ] **Step 2: Update tests — remove area_unit validation test, update existing tests**

In `test/models/budget_setting_test.rb`:

1. Remove the test `"area_unit must be pyeong or sqm"` (lines 44-48)
2. In `"valid with user and available_cash"` test, remove `area_unit: "pyeong"` from the params

- [ ] **Step 3: Run all model tests**

Run: `bin/rails test test/models/budget_setting_test.rb`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add app/models/budget_setting.rb test/models/budget_setting_test.rb
git commit -m "refactor(model): remove area_unit validation and unit conversion methods"
```

---

### Task 3: Update Onboarding Step2 View — Dropdown UI

**Files:**
- Modify: `app/views/onboardings/step2.html.erb`
- Modify: `app/controllers/onboardings_controller.rb`
- Modify: `test/controllers/onboardings_controller_test.rb`

- [ ] **Step 1: Update controller — remove area_unit from params, remove convert_area_to_sqm!, update defaults**

In `app/controllers/onboardings_controller.rb`:

1. In `create_step2` (line 29): remove `@setting.convert_area_to_sqm!`
2. In `step2_params` (line 91): remove `:area_unit` from the array
3. In `apply_step2_defaults` (lines 108-115): replace with:

```ruby
def apply_step2_defaults
  return if @setting.area_range_min.present?

  @setting.area_range_min = 60  # 중형·국평 lower bound
  @setting.area_range_max = 85  # 중형·국평 upper bound
  @setting.property_type_id ||= @property_types.first&.id
end
```

- [ ] **Step 2: Replace step2 view area section**

In `app/views/onboardings/step2.html.erb`, replace the unit selection section (lines 22-39) and the area number fields (lines 41-63) with:

Remove `data-reserve-fund-unit-value` attribute from the controller div (line 10). Change to:

```erb
<div data-controller="reserve-fund"
     data-reserve-fund-defaults-value="<%= @reserve_defaults.to_json %>">
```

Replace the entire `<%# 면적 단위 선택 %>` section (lines 22-39) — delete it entirely.

Replace the `<%# 면적 범위 %>` section (lines 41-63) with:

```erb
<%# 면적 범위 %>
<div class="mb-4 grid grid-cols-2 gap-4">
  <div>
    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">면적 최소</label>
    <%= select_tag "budget_setting[area_range_min]",
      options_for_select(BudgetSetting.area_min_options, @setting.area_range_min),
      class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500",
      data: { reserve_fund_target: "areaMin",
              action: "change->reserve-fund#areaChanged" } %>
  </div>
  <div>
    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">면적 최대</label>
    <%= select_tag "budget_setting[area_range_max]",
      options_for_select(BudgetSetting.area_max_options, @setting.area_range_max),
      class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500",
      data: { reserve_fund_target: "areaMax",
              action: "change->reserve-fund#areaChanged" } %>
  </div>
</div>
```

- [ ] **Step 3: Update controller test — remove area_unit from params**

In `test/controllers/onboardings_controller_test.rb`, update all `step2` POST params to remove `area_unit: "pyeong"` and use valid category boundary values. For example in the step2 test (line 33-51), change to:

```ruby
post step2_onboarding_url, params: {
  budget_setting: {
    property_type_id: apt.id,
    area_range_min: 40,
    area_range_max: 85,
    repair_cost: 500,
    acquisition_tax: 360,
    scrivener_fee: 80,
    moving_cost: 150,
    maintenance_fee: 50
  }
}
```

Do the same for the step3 test (line 61-65) — remove `area_unit` and use boundary values:
```ruby
area_range_min: 40, area_range_max: 85,
```

Also update the "returning user" test (lines 98-105) — remove `area_unit: "pyeong"` from `BudgetSetting.create!` params.

And the "complete" test (lines 117-122) — remove `area_unit: "pyeong"`.

- [ ] **Step 4: Run onboarding controller tests**

Run: `bin/rails test test/controllers/onboardings_controller_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/views/onboardings/step2.html.erb app/controllers/onboardings_controller.rb test/controllers/onboardings_controller_test.rb
git commit -m "feat(onboarding): replace area number inputs with category dropdowns"
```

---

### Task 4: Update Settings Budget View — Dropdown UI

**Files:**
- Modify: `app/views/settings/budgets/show.html.erb`
- Modify: `app/controllers/settings/budgets_controller.rb`
- Modify: `test/controllers/settings/budgets_controller_test.rb`

- [ ] **Step 1: Update controller — remove area_unit from params, remove convert_area_to_sqm!**

In `app/controllers/settings/budgets_controller.rb`:

1. In `update` (line 14): remove `@setting.convert_area_to_sqm!`
2. In `budget_params` (line 51): remove `:area_unit` from the array

- [ ] **Step 2: Replace area section in settings view**

In `app/views/settings/budgets/show.html.erb`, replace the entire `data-controller="area-unit"` block (lines 43-76) with:

```erb
<div class="mb-4 grid grid-cols-2 gap-4">
  <div>
    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">면적 최소</label>
    <%= select_tag "budget_setting[area_range_min]",
      options_for_select(BudgetSetting.area_min_options, @setting.area_range_min),
      class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500" %>
  </div>
  <div>
    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">면적 최대</label>
    <%= select_tag "budget_setting[area_range_max]",
      options_for_select(BudgetSetting.area_max_options, @setting.area_range_max),
      class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500" %>
  </div>
</div>
```

- [ ] **Step 3: Update controller test — remove area_unit from params**

In `test/controllers/settings/budgets_controller_test.rb`:

1. In `setup` (line 7-25): remove `area_unit: "pyeong"` from `BudgetSetting.create!`
2. In PATCH test (line 34-49): remove `area_unit: "pyeong"` and use boundary values:

```ruby
patch settings_budget_url, params: {
  budget_setting: {
    available_cash: 40000,
    property_type_id: property_types(:apartment).id,
    area_range_min: 40,
    area_range_max: 85,
    repair_cost: 500,
    acquisition_tax: 360,
    scrivener_fee: 80,
    moving_cost: 150,
    maintenance_fee: 50,
    loan_policy_id: loan_policies(:auction_bank_apartment).id,
    loan_ratio: 0.7,
    failed_auction_rounds: 0
  }
}
```

- [ ] **Step 4: Run settings controller tests**

Run: `bin/rails test test/controllers/settings/budgets_controller_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/views/settings/budgets/show.html.erb app/controllers/settings/budgets_controller.rb test/controllers/settings/budgets_controller_test.rb
git commit -m "feat(settings): replace area number inputs with category dropdowns"
```

---

### Task 5: Update Stimulus Controller — Remove Unit Conversion

**Files:**
- Modify: `app/javascript/controllers/reserve_fund_controller.js`
- Delete: `app/javascript/controllers/area_unit_controller.js`

- [ ] **Step 1: Simplify reserve_fund_controller.js**

Replace the full file content with:

```javascript
import { Controller } from "@hotwired/stimulus"

// Manages Step 2 reserve fund form:
// - Area dropdown change triggers auto-recalculation of reserve defaults
// - "자동 계산" checkbox: when checked, fills reserve items based on average area
// - Maintains running total of all reserve items
export default class extends Controller {
  static targets = [
    "autoCalc", "propertyType",
    "areaMin", "areaMax",
    "repairCost", "acquisitionTax", "scrivenerFee",
    "movingCost", "maintenanceFee", "total",
    "repairCostHint", "acquisitionTaxHint", "scrivenerFeeHint",
    "movingCostHint", "maintenanceFeeHint"
  ]
  static values = {
    defaults: Object // reserve_fund_defaults grouped by property_type_id
  }

  connect() {
    this.updateTotal()
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
  }

  // Called when "자동 계산" checkbox changes
  toggleAutoCalc() {
    if (this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
  }

  // Called when property type changes
  propertyTypeChanged() {
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
    this.updateTotal()
  }

  // Called when area dropdown changes
  areaChanged() {
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
    this.updateTotal()
  }

  // Apply default reserve values based on property type and average area
  applyDefaults() {
    const propertyTypeId = this.propertyTypeTarget.value
    const defaults = this.defaultsValue[propertyTypeId]

    if (!defaults || defaults.length === 0) return

    // Dropdown values are already in ㎡
    const minVal = parseInt(this.areaMinTarget.value, 10) || 0
    const maxVal = parseInt(this.areaMaxTarget.value, 10) || 0
    const avgArea = (minVal + maxVal) / 2

    // Find matching default by average area
    const match = defaults.find(d =>
      avgArea >= d.area_range_min && avgArea <= d.area_range_max
    )

    if (match) {
      this.repairCostTarget.value = match.repair_cost
      this.acquisitionTaxTarget.value = Math.round(match.acquisition_tax_rate * 10000)
      this.scrivenerFeeTarget.value = match.scrivener_fee
      this.movingCostTarget.value = match.moving_cost
      this.maintenanceFeeTarget.value = match.maintenance_fee
      this.updateTotal()
      this.updateHints(match)
    }
  }

  updateHints(match) {
    const areaLabel = `${match.area_range_min}~${match.area_range_max}㎡`
    const taxPercent = (match.acquisition_tax_rate * 100).toFixed(1)

    if (this.hasRepairCostHintTarget)
      this.repairCostHintTarget.textContent = `${areaLabel} 기준 수선비`
    if (this.hasAcquisitionTaxHintTarget)
      this.acquisitionTaxHintTarget.textContent = `감정가 × ${taxPercent}% (취득세율)`
    if (this.hasScrivenerFeeHintTarget)
      this.scrivenerFeeHintTarget.textContent = `${areaLabel} 기준 법무사 수수료`
    if (this.hasMovingCostHintTarget)
      this.movingCostHintTarget.textContent = `${areaLabel} 기준 이사비`
    if (this.hasMaintenanceFeeHintTarget)
      this.maintenanceFeeHintTarget.textContent = `미납 관리비 (없으면 0)`
  }

  updateTotal() {
    const fields = [
      this.repairCostTarget,
      this.acquisitionTaxTarget,
      this.scrivenerFeeTarget,
      this.movingCostTarget,
      this.maintenanceFeeTarget
    ]
    const total = fields.reduce((sum, field) => {
      return sum + (parseInt(String(field.value).replace(/,/g, ""), 10) || 0)
    }, 0)

    this.totalTarget.textContent = total.toLocaleString("ko-KR")
  }
}
```

- [ ] **Step 2: Delete area_unit_controller.js**

```bash
git rm app/javascript/controllers/area_unit_controller.js
```

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/reserve_fund_controller.js
git commit -m "refactor(stimulus): remove unit conversion logic, simplify reserve fund controller"
```

---

### Task 6: Update Snapshot Service and Fixture

**Files:**
- Modify: `app/services/budget_snapshot_service.rb`
- Modify: `test/services/budget_snapshot_service_test.rb`
- Modify: `test/fixtures/budget_settings.yml`

- [ ] **Step 1: Update snapshot service — stop passing area_unit**

In `app/services/budget_snapshot_service.rb`:

1. In `create` method (line 41): remove `area_unit: setting.area_unit,`
2. In `recalculate` method (line 68): remove `area_unit: setting.area_unit,`

- [ ] **Step 2: Update snapshot service test — remove area_unit from setup**

In `test/services/budget_snapshot_service_test.rb`, line 20: remove `area_unit: "pyeong",` from the `BudgetSetting.create!` call.

- [ ] **Step 3: Update fixture — remove area_unit**

In `test/fixtures/budget_settings.yml`, remove the line `area_unit: pyeong`.

- [ ] **Step 4: Run snapshot service tests**

Run: `bin/rails test test/services/budget_snapshot_service_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/budget_snapshot_service.rb test/services/budget_snapshot_service_test.rb test/fixtures/budget_settings.yml
git commit -m "refactor(snapshot): stop passing area_unit to snapshots"
```

---

### Task 7: Migration — Remove area_unit Column

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_remove_area_unit_from_budget_settings.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration RemoveAreaUnitFromBudgetSettings
```

- [ ] **Step 2: Write migration content**

```ruby
class RemoveAreaUnitFromBudgetSettings < ActiveRecord::Migration[8.1]
  def change
    remove_column :budget_settings, :area_unit, :string, default: "pyeong", null: false
  end
end
```

- [ ] **Step 3: Run migration**

```bash
bin/rails db:migrate
```

- [ ] **Step 4: Run full test suite**

```bash
bin/rails test
```

Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*_remove_area_unit_from_budget_settings.rb db/schema.rb
git commit -m "migrate: remove area_unit column from budget_settings"
```

---

### Task 8: Final Verification

- [ ] **Step 1: Run rubocop**

```bash
bin/rubocop
```

Fix any issues.

- [ ] **Step 2: Run brakeman security scan**

```bash
bin/brakeman --quiet --no-pager
```

- [ ] **Step 3: Run full test suite one more time**

```bash
bin/rails test
```

Expected: All PASS

- [ ] **Step 4: Commit any fixes**

Only if rubocop/brakeman required changes:

```bash
git add -A
git commit -m "fix: address rubocop/brakeman findings from area dropdown migration"
```
