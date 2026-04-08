# Remove Failed Auction Rounds Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove `failed_auction_rounds` and `searchable_appraisal_limit` from the entire codebase — the court already provides these values via API.

**Architecture:** This is a feature removal. Work bottom-up: DB migration first, then models/services, controllers, views/JS, tests, and finally docs cleanup. Each task is independently committable.

**Tech Stack:** Rails 8.1, Stimulus JS, Minitest, SQLite

**Spec:** `docs/superpowers/specs/2026-04-08-remove-failed-auction-rounds-design.md`

---

### Task 1: Create DB migration to drop columns

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_remove_failed_auction_rounds_columns.rb`

- [ ] **Step 1: Generate the migration**

Run:
```bash
bin/rails generate migration RemoveFailedAuctionRoundsColumns
```

- [ ] **Step 2: Write the migration**

Edit the generated file to contain:

```ruby
class RemoveFailedAuctionRoundsColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :budget_settings, :failed_auction_rounds, :integer, default: 0
    remove_column :budget_settings, :searchable_appraisal_limit, :integer
    remove_column :budget_snapshots, :failed_auction_rounds, :integer
    remove_column :budget_snapshots, :searchable_appraisal_limit, :integer
  end
end
```

- [ ] **Step 3: Run the migration**

Run: `bin/rails db:migrate`
Expected: Migration runs successfully, `db/schema.rb` updated — those 4 columns are gone.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_remove_failed_auction_rounds_columns.rb db/schema.rb
git commit -m "db: drop failed_auction_rounds and searchable_appraisal_limit columns"
```

---

### Task 2: Update BudgetCalculationService

**Files:**
- Modify: `app/services/budget_calculation_service.rb`
- Modify: `test/services/budget_calculation_service_test.rb`

- [ ] **Step 1: Update the test file**

Replace `test/services/budget_calculation_service_test.rb` entirely:

```ruby
require "test_helper"

class BudgetCalculationServiceTest < ActiveSupport::TestCase
  test "calculates max_bid_amount correctly" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
      loan_ratio: 0.7
    )

    # (30000 - 1140) / (1 - 0.7) = 28860 / 0.3 = 96200
    assert_equal 96200, result[:max_bid_amount]
    assert_equal 1140, result[:total_reserves]
  end

  test "calculates with zero loan ratio" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
      loan_ratio: 0.0
    )

    # (30000 - 1140) / (1 - 0) = 28860
    assert_equal 28860, result[:max_bid_amount]
  end

  test "returns breakdown with all reserve items" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
      loan_ratio: 0.7
    )

    assert_equal 500, result[:breakdown][:repair]
    assert_equal 360, result[:breakdown][:acquisition_tax]
    assert_equal 80, result[:breakdown][:scrivener]
    assert_equal 150, result[:breakdown][:moving]
    assert_equal 50, result[:breakdown][:maintenance]
    assert_equal 30000, result[:breakdown][:available_cash]
    assert_equal 0.7, result[:breakdown][:loan_ratio]
  end

  test "raises error when available_cash is less than reserves" do
    assert_raises(BudgetCalculationService::InsufficientFundsError) do
      BudgetCalculationService.call(
        available_cash: 500,
        reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
        loan_ratio: 0.7
      )
    end
  end

  test "handles missing reserve fund items as zero" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500 },
      loan_ratio: 0.7
    )

    # (30000 - 500) / 0.3 = 98333
    assert_equal 98333, result[:max_bid_amount]
    assert_equal 500, result[:total_reserves]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/budget_calculation_service_test.rb`
Expected: FAIL — service still expects `failed_auction_rounds` param.

- [ ] **Step 3: Update the service**

Replace `app/services/budget_calculation_service.rb`:

```ruby
class BudgetCalculationService
  class InsufficientFundsError < StandardError; end

  RESERVE_KEYS = %i[repair acquisition_tax scrivener moving maintenance].freeze

  def self.call(available_cash:, reserve_funds:, loan_ratio:)
    new(available_cash:, reserve_funds:, loan_ratio:).call
  end

  def initialize(available_cash:, reserve_funds:, loan_ratio:)
    @available_cash = available_cash
    @reserve_funds = reserve_funds
    @loan_ratio = loan_ratio.to_d
  end

  def call
    total_reserves = RESERVE_KEYS.sum { |key| @reserve_funds.fetch(key, 0).to_i }

    raise ArgumentError, "available_cash is required" if @available_cash.nil?

    net_cash = @available_cash - total_reserves
    raise InsufficientFundsError, "Available cash (#{@available_cash}) is less than total reserves (#{total_reserves})" if net_cash <= 0

    divisor = 1 - @loan_ratio
    max_bid_amount = (net_cash / divisor).floor

    {
      total_reserves: total_reserves,
      max_bid_amount: max_bid_amount,
      breakdown: {
        available_cash: @available_cash,
        repair: @reserve_funds.fetch(:repair, 0).to_i,
        acquisition_tax: @reserve_funds.fetch(:acquisition_tax, 0).to_i,
        scrivener: @reserve_funds.fetch(:scrivener, 0).to_i,
        moving: @reserve_funds.fetch(:moving, 0).to_i,
        maintenance: @reserve_funds.fetch(:maintenance, 0).to_i,
        loan_ratio: @loan_ratio.to_f
      }
    }
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/budget_calculation_service_test.rb`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/budget_calculation_service.rb test/services/budget_calculation_service_test.rb
git commit -m "refactor: remove failed_auction_rounds from BudgetCalculationService"
```

---

### Task 3: Update BudgetSnapshotService

**Files:**
- Modify: `app/services/budget_snapshot_service.rb`
- Modify: `test/services/budget_snapshot_service_test.rb`

- [ ] **Step 1: Update the test file**

Replace `test/services/budget_snapshot_service_test.rb`:

```ruby
require "test_helper"

class BudgetSnapshotServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @setting = BudgetSetting.create!(
      user: @user,
      available_cash: 30000,
      property_type: property_types(:apartment),
      area_range_min: 59,
      area_range_max: 84,
      repair_cost: 500,
      acquisition_tax: 360,
      scrivener_fee: 80,
      moving_cost: 150,
      maintenance_fee: 50,
      loan_policy: loan_policies(:auction_bank_apartment),
      loan_ratio: 0.7,
      max_bid_amount: 96200,
      completed_at: Time.current
    )
  end

  test "create builds snapshot from current budget_settings" do
    snapshot = BudgetSnapshotService.create(user: @user, trigger: "onboarding")

    assert_equal 1, snapshot.version
    assert_equal "onboarding", snapshot.trigger
    assert_equal 30000, snapshot.available_cash
    assert_equal "아파트", snapshot.property_type_name
    assert_equal "59~84㎡", snapshot.area_range
    assert_equal 0.7, snapshot.loan_ratio.to_f
    assert_equal "경락대출 (1금융)", snapshot.loan_policy_name
    assert_equal 96200, snapshot.max_bid_amount
    assert_nil snapshot.parent_snapshot_id
    assert snapshot.calculated_at.present?
  end

  test "create increments version for same user" do
    s1 = BudgetSnapshotService.create(user: @user, trigger: "onboarding")
    s2 = BudgetSnapshotService.create(user: @user, trigger: "manual_edit")

    assert_equal 1, s1.version
    assert_equal 2, s2.version
  end

  test "recalculate creates new snapshot with parent reference" do
    original = BudgetSnapshotService.create(user: @user, trigger: "onboarding")

    @setting.update!(loan_ratio: 0.6, max_bid_amount: 72150)

    recalculated = BudgetSnapshotService.recalculate(user: @user, parent_snapshot: original)

    assert_equal 2, recalculated.version
    assert_equal "recalculate", recalculated.trigger
    assert_equal original.id, recalculated.parent_snapshot_id
    assert_equal 0.6, recalculated.loan_ratio.to_f
    assert_equal 72150, recalculated.max_bid_amount
  end

  test "compare returns diff between two snapshots" do
    s1 = BudgetSnapshotService.create(user: @user, trigger: "onboarding")

    @setting.update!(loan_ratio: 0.6, max_bid_amount: 72150)
    s2 = BudgetSnapshotService.create(user: @user, trigger: "manual_edit")

    diff = BudgetSnapshotService.compare(snapshot_a: s1, snapshot_b: s2)

    assert_equal({ was: 0.7, now: 0.6 }, diff[:loan_ratio])
    assert_equal({ was: 96200, now: 72150, delta: -24050 }, diff[:max_bid_amount])
  end

  test "compare returns empty hash when snapshots are identical" do
    s1 = BudgetSnapshotService.create(user: @user, trigger: "onboarding")
    s2 = BudgetSnapshotService.create(user: @user, trigger: "manual_edit")

    diff = BudgetSnapshotService.compare(snapshot_a: s1, snapshot_b: s2)
    assert_empty diff
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/budget_snapshot_service_test.rb`
Expected: FAIL — service still references removed columns.

- [ ] **Step 3: Update the service**

Replace `app/services/budget_snapshot_service.rb`:

```ruby
class BudgetSnapshotService
  COMPARABLE_FIELDS = %i[
    available_cash repair_cost acquisition_tax scrivener_fee
    moving_cost maintenance_fee loan_ratio max_bid_amount
  ].freeze

  NUMERIC_FIELDS = %i[
    available_cash repair_cost acquisition_tax scrivener_fee
    moving_cost maintenance_fee max_bid_amount
  ].freeze

  def self.create(user:, trigger:)
    new(user:).create(trigger:)
  end

  def self.recalculate(user:, parent_snapshot:)
    new(user:).recalculate(parent_snapshot:)
  end

  def self.compare(snapshot_a:, snapshot_b:)
    new(user: snapshot_a.user).compare(snapshot_a:, snapshot_b:)
  end

  def initialize(user:)
    @user = user
  end

  def create(trigger:)
    setting = @user.budget_setting
    version = BudgetSnapshot.next_version_for(@user.id)

    BudgetSnapshot.create!(
      user: @user,
      version: version,
      trigger: trigger,
      available_cash: setting.available_cash,
      property_type_name: setting.property_type&.name,
      area_range: format_area_range(setting),
      repair_cost: setting.repair_cost,
      acquisition_tax: setting.acquisition_tax,
      scrivener_fee: setting.scrivener_fee,
      moving_cost: setting.moving_cost,
      maintenance_fee: setting.maintenance_fee,
      loan_policy_name: setting.loan_policy&.policy_name,
      loan_ratio: setting.loan_ratio,
      max_bid_amount: setting.max_bid_amount,
      calculated_at: Time.current
    )
  end

  def recalculate(parent_snapshot:)
    setting = @user.budget_setting
    version = BudgetSnapshot.next_version_for(@user.id)

    BudgetSnapshot.create!(
      user: @user,
      version: version,
      trigger: "recalculate",
      parent_snapshot: parent_snapshot,
      available_cash: setting.available_cash,
      property_type_name: setting.property_type&.name,
      area_range: format_area_range(setting),
      repair_cost: setting.repair_cost,
      acquisition_tax: setting.acquisition_tax,
      scrivener_fee: setting.scrivener_fee,
      moving_cost: setting.moving_cost,
      maintenance_fee: setting.maintenance_fee,
      loan_policy_name: setting.loan_policy&.policy_name,
      loan_ratio: setting.loan_ratio,
      max_bid_amount: setting.max_bid_amount,
      calculated_at: Time.current
    )
  end

  def compare(snapshot_a:, snapshot_b:)
    diff = {}

    COMPARABLE_FIELDS.each do |field|
      val_a = normalize_value(snapshot_a.public_send(field))
      val_b = normalize_value(snapshot_b.public_send(field))

      next if val_a == val_b

      entry = { was: val_a, now: val_b }
      entry[:delta] = val_b - val_a if NUMERIC_FIELDS.include?(field) && val_a.is_a?(Numeric) && val_b.is_a?(Numeric)
      diff[field] = entry
    end

    diff
  end

  private

  def format_area_range(setting)
    return nil unless setting.area_range_min && setting.area_range_max
    "#{setting.area_range_min}~#{setting.area_range_max}㎡"
  end

  def normalize_value(val)
    val.is_a?(BigDecimal) ? val.to_f : val
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/budget_snapshot_service_test.rb`
Expected: All 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/budget_snapshot_service.rb test/services/budget_snapshot_service_test.rb
git commit -m "refactor: remove failed_auction_rounds from BudgetSnapshotService"
```

---

### Task 4: Update model and helper

**Files:**
- Modify: `app/models/budget_setting.rb`
- Modify: `app/helpers/application_helper.rb`
- Modify: `test/models/budget_setting_test.rb`
- Modify: `test/models/budget_snapshot_test.rb`
- Modify: `test/helpers/application_helper_test.rb`
- Modify: `test/fixtures/budget_settings.yml`

- [ ] **Step 1: Update BudgetSetting model — remove validation**

In `app/models/budget_setting.rb`, remove lines 9–11 (the `validates :failed_auction_rounds` block):

```ruby
  validates :failed_auction_rounds, numericality: {
    only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3
  }
```

- [ ] **Step 2: Remove `appraisal_limits_by_round` from helper**

In `app/helpers/application_helper.rb`, delete lines 26–35 (the entire method and its comment). The file should only contain `format_price_in_eok`.

- [ ] **Step 3: Update fixture**

Replace `test/fixtures/budget_settings.yml`:

```yaml
completed:
  user: budget_user
  available_cash: 30000
  property_type: apartment
  loan_policy: auction_bank_apartment
  loan_ratio: 0.7
  repair_cost: 500
  acquisition_tax: 360
  scrivener_fee: 80
  moving_cost: 150
  maintenance_fee: 50
  max_bid_amount: 96200
  area_range_min: 59
  area_range_max: 84
  completed_at: <%= Time.current %>
```

- [ ] **Step 4: Update BudgetSetting test**

In `test/models/budget_setting_test.rb`:

Remove `failed_auction_rounds: 0, searchable_appraisal_limit: 85333` from the "valid with user and available_cash" test (line 13).

Remove `failed_auction_rounds: 0` from the "invalid with duplicate user_id" test (line 21).

Delete the "failed_auction_rounds must be 0-3" test entirely (lines 39–42).

- [ ] **Step 5: Update BudgetSnapshot test**

In `test/models/budget_snapshot_test.rb`, in the "valid with required fields" test (lines 4–16):

Remove `failed_auction_rounds: 0,` and `searchable_appraisal_limit: 85333,` from the `BudgetSnapshot.new()` call (lines 12–13).

- [ ] **Step 6: Update ApplicationHelper test**

In `test/helpers/application_helper_test.rb`, delete lines 40–71 (the entire `appraisal_limits_by_round` test section, including the comment on line 40).

- [ ] **Step 7: Run all affected tests**

Run:
```bash
bin/rails test test/models/budget_setting_test.rb test/models/budget_snapshot_test.rb test/helpers/application_helper_test.rb
```
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/models/budget_setting.rb app/helpers/application_helper.rb test/models/budget_setting_test.rb test/models/budget_snapshot_test.rb test/helpers/application_helper_test.rb test/fixtures/budget_settings.yml
git commit -m "refactor: remove failed_auction_rounds from model, helper, and their tests"
```

---

### Task 5: Update controllers

**Files:**
- Modify: `app/controllers/onboardings_controller.rb`
- Modify: `app/controllers/settings/budgets_controller.rb`
- Modify: `test/controllers/onboardings_controller_test.rb`
- Modify: `test/controllers/settings/budgets_controller_test.rb`
- Modify: `test/controllers/settings/budget_snapshots_controller_test.rb`
- Modify: `test/controllers/home_controller_test.rb`

- [ ] **Step 1: Update OnboardingsController**

In `app/controllers/onboardings_controller.rb`:

**Line 63:** Remove `failed_auction_rounds: @setting.failed_auction_rounds` from the `BudgetCalculationService.call()` arguments.

**Line 67:** Remove `@setting.searchable_appraisal_limit = result[:searchable_appraisal_limit]`.

**Line 101:** Change `step3_params` to:
```ruby
  def step3_params
    params.expect(budget_setting: [ :loan_policy_id, :loan_ratio ])
  end
```

- [ ] **Step 2: Update Settings::BudgetsController**

In `app/controllers/settings/budgets_controller.rb`:

**Line 30:** Remove `failed_auction_rounds: @setting.failed_auction_rounds` from the `BudgetCalculationService.call()` arguments.

**Line 34:** Remove `@setting.searchable_appraisal_limit = result[:searchable_appraisal_limit]`.

**Line 53–59:** Change `budget_params` to:
```ruby
    def budget_params
      params.expect(budget_setting: [
        :available_cash, :property_type_id, :area_category,
        :repair_cost, :acquisition_tax, :scrivener_fee,
        :moving_cost, :maintenance_fee, :loan_policy_id, :loan_ratio
      ])
    end
```

- [ ] **Step 3: Update OnboardingsController test**

In `test/controllers/onboardings_controller_test.rb`:

**Line 71:** Remove `failed_auction_rounds: 2` from the step3 POST params. The params block becomes:
```ruby
    post step3_onboarding_url, params: {
      budget_setting: {
        loan_policy_id: policy.id,
        loan_ratio: 0.7
      }
    }
```

**Lines 100–103:** In "GET step1 renders budget summary with values for returning user", remove `failed_auction_rounds: 0,` and `searchable_appraisal_limit: 96200,` from `BudgetSetting.create!`.

**Lines 119–120:** In "GET complete shows results", remove `failed_auction_rounds: 0, searchable_appraisal_limit: 96200,` from `BudgetSetting.create!`.

- [ ] **Step 4: Update Settings::BudgetsController test**

In `test/controllers/settings/budgets_controller_test.rb`:

**Lines 21–22:** In setup, remove `failed_auction_rounds: 0,` and `searchable_appraisal_limit: 96200,` from `BudgetSetting.create!`.

**Line 45:** In "PATCH update" test, remove `failed_auction_rounds: 0` from the params hash.

- [ ] **Step 5: Update Settings::BudgetSnapshotsController test**

In `test/controllers/settings/budget_snapshots_controller_test.rb`:

**Line 10:** Remove `failed_auction_rounds: 0, searchable_appraisal_limit: 96200,` from `BudgetSetting.create!`.

- [ ] **Step 6: Update HomeController test**

In `test/controllers/home_controller_test.rb`:

**Line 17:** Remove `failed_auction_rounds: 0,` from `BudgetSetting.create!`.

- [ ] **Step 7: Run all controller tests**

Run:
```bash
bin/rails test test/controllers/
```
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/onboardings_controller.rb app/controllers/settings/budgets_controller.rb test/controllers/
git commit -m "refactor: remove failed_auction_rounds from controllers and controller tests"
```

---

### Task 6: Update views

**Files:**
- Modify: `app/views/onboardings/step3.html.erb`
- Modify: `app/views/onboardings/complete.html.erb`
- Modify: `app/views/settings/budgets/show.html.erb`
- Modify: `app/views/inspections/_layout.html.erb`
- Modify: `app/views/settings/budget_snapshots/show.html.erb`
- Modify: `app/views/settings/budget_snapshots/compare.html.erb`

- [ ] **Step 1: Update onboarding step3**

In `app/views/onboardings/step3.html.erb`:

**Line 4:** Change description to:
```erb
    description: "대출 정책을 설정하여 최대 입찰가를 계산합니다",
```

**Delete line 64:** Remove `<div data-loan-slider-target="roundBreakdown" class="mb-6"></div>`.

**Delete lines 66–79:** Remove the entire "유찰 회차" slider section (label, range input, display spans).

**Delete lines 81–84:** Remove the "검색 가능 감정가 상한" preview card.

After these deletions, the submit button section should follow directly after the "예상 최대입찰가" card and the disclaimer text.

- [ ] **Step 2: Update onboarding complete**

In `app/views/onboardings/complete.html.erb`:

Delete lines 13–20 (the entire `if @setting.failed_auction_rounds.to_i > 0` conditional block including the amber info box).

- [ ] **Step 3: Update budget settings show**

In `app/views/settings/budgets/show.html.erb`:

**Lines 91–93:** Delete the "유찰 회차" `<div>` block (label + number_field).

**Line 83:** Change `grid grid-cols-2 gap-4` to just a plain `<div>` (no grid needed with only one item):
```erb
      <div class="mb-4">
```

- [ ] **Step 4: Update inspection layout**

In `app/views/inspections/_layout.html.erb`:

Delete lines 25–31 (the `appraisal_limits_by_round` loop rendering emerald badges).

- [ ] **Step 5: Update budget snapshot show**

In `app/views/settings/budget_snapshots/show.html.erb`:

Delete these two rows from the `SummaryTableComponent` rows array (lines 41–42):
```erb
        { label: "유찰 회차", value: "#{@snapshot.failed_auction_rounds}회차" },
        { label: "검색 가능 감정가", value: format_price_in_eok(@snapshot.searchable_appraisal_limit) }
```

The last row in the array should now be `{ label: "대출 비율 (LTV)", ... }`. Ensure no trailing comma issues.

- [ ] **Step 6: Update budget snapshot compare**

In `app/views/settings/budget_snapshots/compare.html.erb`:

Delete these two entries from the `field_labels` hash (lines 38–39):
```erb
        failed_auction_rounds: "유찰 회차",
        searchable_appraisal_limit: "검색 가능 감정가"
```

The last entry should now be `max_bid_amount: "최대입찰가"`. Ensure no trailing comma issues.

- [ ] **Step 7: Run full test suite**

Run: `bin/rails test`
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/views/onboardings/step3.html.erb app/views/onboardings/complete.html.erb app/views/settings/budgets/show.html.erb app/views/inspections/_layout.html.erb app/views/settings/budget_snapshots/show.html.erb app/views/settings/budget_snapshots/compare.html.erb
git commit -m "refactor: remove failed auction rounds UI from all views"
```

---

### Task 7: Simplify JavaScript controllers

**Files:**
- Modify: `app/javascript/controllers/loan_slider_controller.js`
- Delete: `app/javascript/controllers/failed_rounds_controller.js`
- Delete: `test/system/onboarding_round_breakdown_test.rb`

- [ ] **Step 1: Replace loan_slider_controller.js**

Replace `app/javascript/controllers/loan_slider_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Handles loan ratio slider with real-time max bid preview.
export default class extends Controller {
  static targets = ["slider", "ratioDisplay", "maxBidPreview", "hiddenRatio"]
  static values = {
    availableCash: Number,
    totalReserves: Number
  }

  connect() {
    this.updateAll()
  }

  selectPolicy(event) {
    const ratio = parseFloat(event.target.dataset.loanRatio)
    this.sliderTarget.value = Math.round(ratio * 100)
    this.updateAll()
  }

  slide() {
    this.updateAll()
  }

  updateAll() {
    const ratio = parseInt(this.sliderTarget.value, 10) / 100
    this.ratioDisplayTarget.textContent = `${Math.round(ratio * 100)}%`
    this.hiddenRatioTarget.value = ratio

    const netCash = this.availableCashValue - this.totalReservesValue
    if (netCash <= 0 || ratio >= 1) {
      this.maxBidPreviewTarget.textContent = "계산 불가"
      return
    }

    const maxBid = Math.floor(netCash / (1 - ratio))
    this.maxBidPreviewTarget.textContent = `${maxBid.toLocaleString("ko-KR")}만원`
  }
}
```

- [ ] **Step 2: Delete failed_rounds_controller.js**

Run:
```bash
rm app/javascript/controllers/failed_rounds_controller.js
```

- [ ] **Step 3: Delete system test for round breakdown**

Run:
```bash
rm test/system/onboarding_round_breakdown_test.rb
```

- [ ] **Step 4: Run tests**

Run: `bin/rails test`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/javascript/controllers/loan_slider_controller.js
git rm app/javascript/controllers/failed_rounds_controller.js
git rm test/system/onboarding_round_breakdown_test.rb
git commit -m "refactor: simplify loan slider controller, remove failed rounds JS"
```

---

### Task 8: Delete obsolete docs

**Files:**
- Delete: `docs/superpowers/specs/2026-04-08-auction-round-price-breakdown-design.md`
- Delete: `docs/superpowers/specs/2026-04-08-failed-auction-round-badges-design.md`
- Delete: `docs/superpowers/plans/2026-04-08-auction-round-price-breakdown.md`
- Delete: `docs/superpowers/plans/2026-04-08-failed-auction-round-badges.md`

- [ ] **Step 1: Delete the 4 obsolete doc files**

Run:
```bash
rm docs/superpowers/specs/2026-04-08-auction-round-price-breakdown-design.md
rm docs/superpowers/specs/2026-04-08-failed-auction-round-badges-design.md
rm docs/superpowers/plans/2026-04-08-auction-round-price-breakdown.md
rm docs/superpowers/plans/2026-04-08-failed-auction-round-badges.md
```

- [ ] **Step 2: Commit**

```bash
git rm docs/superpowers/specs/2026-04-08-auction-round-price-breakdown-design.md docs/superpowers/specs/2026-04-08-failed-auction-round-badges-design.md docs/superpowers/plans/2026-04-08-auction-round-price-breakdown.md docs/superpowers/plans/2026-04-08-failed-auction-round-badges.md
git commit -m "docs: remove obsolete failed auction round specs and plans"
```

---

### Task 9: Update SRS and F01 spec

**Files:**
- Modify: `docs/superpowers/specs/2026-04-05-srs-design.md`
- Modify: `docs/superpowers/specs/2026-04-05-f01-onboarding-budget-design.md`

- [ ] **Step 1: Update SRS**

In `docs/superpowers/specs/2026-04-05-srs-design.md`:

- In the glossary, remove the 유찰 entry or update it to note that the app uses court-provided `min_bid_price` directly (not calculated).
- In F01 description, remove references to `failed_auction_rounds` slider and `searchable_appraisal_limit`. Step 3 should only mention loan policy and LTV settings.

- [ ] **Step 2: Update F01 spec**

In `docs/superpowers/specs/2026-04-05-f01-onboarding-budget-design.md`:

- Remove the "Failed Auction Round Pricing" section showing round 0–3 calculations.
- Remove `failed_auction_rounds` from the data model section.
- Remove `searchable_appraisal_limit` from the data model section.
- Step 3 description: remove round slider and appraisal limit preview references.

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-04-05-srs-design.md docs/superpowers/specs/2026-04-05-f01-onboarding-budget-design.md
git commit -m "docs: update SRS and F01 spec to remove failed auction round references"
```

---

### Task 10: Final verification

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests PASS, zero failures.

- [ ] **Step 2: Run linter**

Run: `bin/rubocop`
Expected: No offenses.

- [ ] **Step 3: Grep for leftover references**

Run:
```bash
grep -r "failed_auction_rounds\|searchable_appraisal_limit\|appraisal_limits_by_round\|PRICE_REDUCTION_PER_ROUND\|roundBreakdown\|roundsSlider\|roundsDisplay\|limitPreview\|slideRounds\|failed.rounds" --include="*.rb" --include="*.erb" --include="*.js" --include="*.yml" app/ test/ db/migrate/ config/ | grep -v "remove_failed_auction_rounds"
```

Expected: No matches (only the migration file name may appear, which is filtered out).

- [ ] **Step 4: Verify migration is clean**

Run:
```bash
bin/rails db:migrate:status
```
Expected: All migrations show `up` status.
