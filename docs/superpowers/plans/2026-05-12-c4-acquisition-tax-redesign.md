# C-4 Acquisition Tax Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the static `average_price × tax_rate` 취득세 computation with a bid-amount-linked formula using bracket iteration over a new `AcquisitionTaxRate` lookup table, so the max-bid formula behaves correctly across all price ranges.

**Architecture:** A new `AcquisitionTaxRate` ActiveRecord model holds (property_type × household_tier × price_bucket × regulated × area_over_85) → total_rate rows. A new `AcquisitionTaxCalculator` service exposes `call` (single lookup) and `brackets_for` (array for iteration). `BudgetCalculationService` is rewritten to accept `tax_brackets` and resolve `max_bid_amount` + `acquisition_tax` in a closed-form bracket iteration (≤3 iterations, monotonic convergence). Two controllers (`OnboardingsController`, `Settings::BudgetsController`) are rewired. UI surfaces gain a 주택수 dropdown and a readonly auto-mode input that displays the 산출 근거 inline. Stimulus `reserve_fund_controller.js` runs the same bracket iteration client-side using pre-serialized brackets to avoid AJAX round-trips.

**Tech Stack:** Rails 8.1, Ruby 3.x (`Data.define`), Stimulus, ViewComponent (read-only here), Tailwind, Minitest with fixtures.

---

## File Structure

**Create:**
- `db/migrate/20260512100000_create_acquisition_tax_rates.rb`
- `db/migrate/20260512100100_add_household_tier_and_acquisition_tax_auto_to_budget_settings.rb`
- `db/seeds/acquisition_tax_rates.json`
- `app/models/acquisition_tax_rate.rb`
- `app/services/acquisition_tax_calculator.rb`
- `test/models/acquisition_tax_rate_test.rb`
- `test/services/acquisition_tax_calculator_test.rb`
- `test/fixtures/acquisition_tax_rates.yml`
- `test/system/c4_small_property_regression_test.rb`

**Modify:**
- `db/seeds.rb` — load new JSON, destroy_all+create_all on `AcquisitionTaxRate`
- `app/models/budget_setting.rb` — `HOUSEHOLD_TIERS` constant, validation, `acquisition_tax_auto?`, `area_over_85?`
- `app/services/budget_calculation_service.rb` — new signature with `reserves_excluding_acquisition_tax:`, `tax_brackets:`, `acquisition_tax_override:` and bracket iteration
- `app/controllers/onboardings_controller.rb` — wire `brackets_for` + new service signature in `create_step3`; permit `household_tier`, `acquisition_tax_auto` in step2 params
- `app/controllers/settings/budgets_controller.rb` — same wiring in `update`; permit two new fields
- `app/views/onboardings/step2.html.erb` — household_tier dropdown, readonly auto UI, basis hint
- `app/views/settings/budgets/show.html.erb` — same UI
- `app/views/onboardings/complete.html.erb` — 산출 근거 한 줄 추가
- `app/javascript/controllers/reserve_fund_controller.js` — client-side `computeAuto()` bracket iteration; new values `taxBrackets`, `loanRatio`
- `test/services/budget_calculation_service_test.rb` — rewrite for new signature
- `test/models/budget_setting_test.rb` — add household_tier/auto coverage
- `test/controllers/onboardings_controller_test.rb` — household_tier flow

---

## Task 1: Migration — create `acquisition_tax_rates` table

**Files:**
- Create: `db/migrate/20260512100000_create_acquisition_tax_rates.rb`

- [ ] **Step 1: Write the migration**

```ruby
class CreateAcquisitionTaxRates < ActiveRecord::Migration[8.1]
  def change
    create_table :acquisition_tax_rates do |t|
      t.references :property_type, null: false, foreign_key: true
      t.string  :household_tier, null: false
      t.boolean :regulated_region
      t.integer :price_bucket_min_manwon, null: false, default: 0
      t.integer :price_bucket_max_manwon
      t.boolean :area_over_85
      t.decimal :total_rate, precision: 5, scale: 4, null: false
      t.timestamps
    end

    add_index :acquisition_tax_rates,
              [ :property_type_id, :household_tier, :regulated_region, :area_over_85 ],
              name: "index_acquisition_tax_rates_on_lookup"
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: `CreateAcquisitionTaxRates: migrated` line printed.

- [ ] **Step 3: Verify schema**

Run: `bin/rails runner "puts AcquisitionTaxRate.connection.columns(:acquisition_tax_rates).map(&:name).inspect"`
Note: `AcquisitionTaxRate` constant does not exist yet — fall back to: `bin/rails runner "puts ActiveRecord::Base.connection.columns(:acquisition_tax_rates).map(&:name).inspect"`
Expected: `["id", "property_type_id", "household_tier", "regulated_region", "price_bucket_min_manwon", "price_bucket_max_manwon", "area_over_85", "total_rate", "created_at", "updated_at"]`

- [ ] **Step 4: Commit (structural)**

```bash
git add db/migrate/20260512100000_create_acquisition_tax_rates.rb db/schema.rb
git commit -m "feat(db): create acquisition_tax_rates table"
```

---

## Task 2: Migration — add columns to `budget_settings`

**Files:**
- Create: `db/migrate/20260512100100_add_household_tier_and_acquisition_tax_auto_to_budget_settings.rb`

- [ ] **Step 1: Write the migration**

```ruby
class AddHouseholdTierAndAcquisitionTaxAutoToBudgetSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :budget_settings, :household_tier, :string, null: false, default: "homeless"
    add_column :budget_settings, :acquisition_tax_auto, :boolean, null: false, default: true
  end
end
```

- [ ] **Step 2: Run the migration**

Run: `bin/rails db:migrate`
Expected: migration succeeds, schema.rb updated.

- [ ] **Step 3: Verify defaults on existing records**

Run: `bin/rails runner "puts BudgetSetting.all.map { |b| [b.id, b.household_tier, b.acquisition_tax_auto].inspect }"`
Expected: every row prints `"homeless"` and `true`.

- [ ] **Step 4: Commit (structural)**

```bash
git add db/migrate/20260512100100_add_household_tier_and_acquisition_tax_auto_to_budget_settings.rb db/schema.rb
git commit -m "feat(db): add household_tier and acquisition_tax_auto to budget_settings"
```

---

## Task 3: Seed data JSON + `db/seeds.rb` wiring

**Files:**
- Create: `db/seeds/acquisition_tax_rates.json`
- Modify: `db/seeds.rb` (insert new loader after reserve_fund_defaults block, before loan_policies)

- [ ] **Step 1: Create seed JSON**

```json
[
  {
    "_comment": "=== 산출 기준 (2026-05-12) — 단순화된 룩업 테이블 ===",
    "_housing_basis": "주택 (1세대 무주택/1주택): 6억 이하 1.1%(85↓)·1.3%(85↑), 6~9억 2.2%(85↓)·2.4%(85↑), 9억+ 3.3%(85↓)·3.5%(85↑). 2주택 비조정=1주택 동일, 조정 8.4%. 3주택+ 비조정 8.4%, 조정 12.4%. 가격 구간 단순화 — 자세한 누진 공식은 follow-up F-C.",
    "_non_housing_basis": "오피스텔/상가/토지: 4.6% (취득 4.0 + 지방교육 0.4 + 농특 0.2), 가격/면적/조정지역 무관"
  },
  {
    "property_type_code": "apartment",
    "rates": [
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": false, "total_rate": "0.0110" },
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": true,  "total_rate": "0.0130" },
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": false, "total_rate": "0.0220" },
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": true,  "total_rate": "0.0240" },
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": false, "total_rate": "0.0330" },
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": true,  "total_rate": "0.0350" },

      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": false, "total_rate": "0.0110" },
      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": true,  "total_rate": "0.0130" },
      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": false, "total_rate": "0.0220" },
      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": true,  "total_rate": "0.0240" },
      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": false, "total_rate": "0.0330" },
      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": true,  "total_rate": "0.0350" },

      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": false, "total_rate": "0.0110" },
      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": true,  "total_rate": "0.0130" },
      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": false, "total_rate": "0.0220" },
      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": true,  "total_rate": "0.0240" },
      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": false, "total_rate": "0.0330" },
      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": true,  "total_rate": "0.0350" },
      { "household_tier": "multi_home_2",    "regulated_region": true,  "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": null,  "area_over_85": null,  "total_rate": "0.0840" },

      { "household_tier": "multi_home_3plus","regulated_region": false, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": null,  "area_over_85": null,  "total_rate": "0.0840" },
      { "household_tier": "multi_home_3plus","regulated_region": true,  "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": null,  "area_over_85": null,  "total_rate": "0.1240" }
    ]
  },
  {
    "property_type_code": "villa",
    "rates": [
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": false, "total_rate": "0.0110" },
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": true,  "total_rate": "0.0130" },
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": false, "total_rate": "0.0220" },
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": true,  "total_rate": "0.0240" },
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": false, "total_rate": "0.0330" },
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": true,  "total_rate": "0.0350" },

      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": false, "total_rate": "0.0110" },
      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": true,  "total_rate": "0.0130" },
      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": false, "total_rate": "0.0220" },
      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": true,  "total_rate": "0.0240" },
      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": false, "total_rate": "0.0330" },
      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": true,  "total_rate": "0.0350" },

      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": false, "total_rate": "0.0110" },
      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": 60000, "area_over_85": true,  "total_rate": "0.0130" },
      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": false, "total_rate": "0.0220" },
      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 60000, "price_bucket_max_manwon": 90000, "area_over_85": true,  "total_rate": "0.0240" },
      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": false, "total_rate": "0.0330" },
      { "household_tier": "multi_home_2",    "regulated_region": false, "price_bucket_min_manwon": 90000, "price_bucket_max_manwon": null,  "area_over_85": true,  "total_rate": "0.0350" },
      { "household_tier": "multi_home_2",    "regulated_region": true,  "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": null,  "area_over_85": null,  "total_rate": "0.0840" },

      { "household_tier": "multi_home_3plus","regulated_region": false, "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": null,  "area_over_85": null,  "total_rate": "0.0840" },
      { "household_tier": "multi_home_3plus","regulated_region": true,  "price_bucket_min_manwon": 0,     "price_bucket_max_manwon": null,  "area_over_85": null,  "total_rate": "0.1240" }
    ]
  },
  {
    "property_type_code": "officetel",
    "rates": [
      { "household_tier": "homeless",        "regulated_region": null, "price_bucket_min_manwon": 0, "price_bucket_max_manwon": null, "area_over_85": null, "total_rate": "0.0460" },
      { "household_tier": "single_home",     "regulated_region": null, "price_bucket_min_manwon": 0, "price_bucket_max_manwon": null, "area_over_85": null, "total_rate": "0.0460" },
      { "household_tier": "multi_home_2",    "regulated_region": null, "price_bucket_min_manwon": 0, "price_bucket_max_manwon": null, "area_over_85": null, "total_rate": "0.0460" },
      { "household_tier": "multi_home_3plus","regulated_region": null, "price_bucket_min_manwon": 0, "price_bucket_max_manwon": null, "area_over_85": null, "total_rate": "0.0460" }
    ]
  }
]
```

- [ ] **Step 2: Wire seed loader into `db/seeds.rb`**

Insert this block after the `reserve_fund_defaults` seeding block (after the line `puts "  -> #{ReserveFundDefault.count} reserve fund defaults"`) and before the `loan_policies` block:

```ruby
puts "Seeding acquisition tax rates..."
tax_data = JSON.parse(File.read(Rails.root.join("db/seeds/acquisition_tax_rates.json")))
tax_data.each do |group|
  next unless group["property_type_code"]
  pt = PropertyType.find_by!(code: group["property_type_code"])
  AcquisitionTaxRate.where(property_type: pt).destroy_all
  group["rates"].each do |attrs|
    AcquisitionTaxRate.create!(
      property_type: pt,
      household_tier: attrs["household_tier"],
      regulated_region: attrs["regulated_region"],
      price_bucket_min_manwon: attrs["price_bucket_min_manwon"],
      price_bucket_max_manwon: attrs["price_bucket_max_manwon"],
      area_over_85: attrs["area_over_85"],
      total_rate: attrs["total_rate"]
    )
  end
end
puts "  -> #{AcquisitionTaxRate.count} acquisition tax rates"
```

- [ ] **Step 3: Defer running seeds**

Skip running `bin/rails db:seed` for now — the `AcquisitionTaxRate` model class doesn't exist yet. Seeds will be exercised after Task 4.

- [ ] **Step 4: Commit (structural)**

```bash
git add db/seeds/acquisition_tax_rates.json db/seeds.rb
git commit -m "feat(seeds): add acquisition_tax_rates seed data and loader"
```

---

## Task 4: `AcquisitionTaxRate` model (Red → Green)

**Files:**
- Create: `app/models/acquisition_tax_rate.rb`
- Create: `test/models/acquisition_tax_rate_test.rb`
- Create: `test/fixtures/acquisition_tax_rates.yml`

- [ ] **Step 1: Create test fixtures**

```yaml
# test/fixtures/acquisition_tax_rates.yml
apartment_homeless_under6_under85:
  property_type: apartment
  household_tier: homeless
  regulated_region: # null
  price_bucket_min_manwon: 0
  price_bucket_max_manwon: 60000
  area_over_85: false
  total_rate: 0.0110

apartment_homeless_under6_over85:
  property_type: apartment
  household_tier: homeless
  price_bucket_min_manwon: 0
  price_bucket_max_manwon: 60000
  area_over_85: true
  total_rate: 0.0130

apartment_homeless_6to9_under85:
  property_type: apartment
  household_tier: homeless
  price_bucket_min_manwon: 60000
  price_bucket_max_manwon: 90000
  area_over_85: false
  total_rate: 0.0220

apartment_homeless_over9_over85:
  property_type: apartment
  household_tier: homeless
  price_bucket_min_manwon: 90000
  price_bucket_max_manwon: # null
  area_over_85: true
  total_rate: 0.0350

apartment_multi2_regulated:
  property_type: apartment
  household_tier: multi_home_2
  regulated_region: true
  price_bucket_min_manwon: 0
  price_bucket_max_manwon: # null
  area_over_85: # null
  total_rate: 0.0840

apartment_multi3plus_regulated:
  property_type: apartment
  household_tier: multi_home_3plus
  regulated_region: true
  price_bucket_min_manwon: 0
  total_rate: 0.1240

apartment_multi3plus_nonregulated:
  property_type: apartment
  household_tier: multi_home_3plus
  regulated_region: false
  price_bucket_min_manwon: 0
  total_rate: 0.0840

officetel_any:
  property_type: officetel
  household_tier: homeless
  price_bucket_min_manwon: 0
  total_rate: 0.0460
```

- [ ] **Step 2: Write failing model test**

```ruby
# test/models/acquisition_tax_rate_test.rb
require "test_helper"

class AcquisitionTaxRateTest < ActiveSupport::TestCase
  test "valid with required fields" do
    rate = AcquisitionTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "homeless",
      price_bucket_min_manwon: 0,
      price_bucket_max_manwon: 60000,
      area_over_85: false,
      total_rate: 0.011
    )
    assert rate.valid?
  end

  test "household_tier must be in HOUSEHOLD_TIERS" do
    rate = AcquisitionTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "invalid_tier",
      price_bucket_min_manwon: 0,
      total_rate: 0.011
    )
    assert_not rate.valid?
    assert_includes rate.errors[:household_tier], "은(는) 목록에 포함되어 있지 않습니다"
  end

  test "total_rate must be present and within bounds" do
    rate = AcquisitionTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "homeless",
      price_bucket_min_manwon: 0
    )
    assert_not rate.valid?
    assert_includes rate.errors[:total_rate], "을(를) 입력해주세요"
  end

  test "HOUSEHOLD_TIERS constant lists all four tiers" do
    assert_equal %w[homeless single_home multi_home_2 multi_home_3plus],
                 AcquisitionTaxRate::HOUSEHOLD_TIERS
  end
end
```

- [ ] **Step 3: Run failing test**

Run: `bin/rails test test/models/acquisition_tax_rate_test.rb`
Expected: FAIL — `NameError: uninitialized constant AcquisitionTaxRate`.

- [ ] **Step 4: Implement the model**

```ruby
# app/models/acquisition_tax_rate.rb
class AcquisitionTaxRate < ApplicationRecord
  HOUSEHOLD_TIERS = %w[homeless single_home multi_home_2 multi_home_3plus].freeze

  belongs_to :property_type

  validates :household_tier, inclusion: { in: HOUSEHOLD_TIERS }
  validates :price_bucket_min_manwon, presence: true,
            numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :total_rate, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 0.20 }
end
```

- [ ] **Step 5: Run tests until green**

Run: `bin/rails test test/models/acquisition_tax_rate_test.rb`
Expected: 4 runs, 0 failures.

- [ ] **Step 6: Run seeds to verify the JSON loads cleanly**

Run: `bin/rails db:seed`
Expected: line `-> 47 acquisition tax rates` (or similar count: apartment 21 + villa 21 + officetel 4 = 46; off-by-one acceptable as long as count > 40 and no error).

- [ ] **Step 7: Commit (behavioral)**

```bash
git add app/models/acquisition_tax_rate.rb test/models/acquisition_tax_rate_test.rb test/fixtures/acquisition_tax_rates.yml
git commit -m "feat(model): add AcquisitionTaxRate with validation"
```

---

## Task 5: `AcquisitionTaxCalculator.call` (Red → Green)

**Files:**
- Create: `app/services/acquisition_tax_calculator.rb`
- Create: `test/services/acquisition_tax_calculator_test.rb`

- [ ] **Step 1: Write failing test for the single-lookup path**

```ruby
# test/services/acquisition_tax_calculator_test.rb
require "test_helper"

class AcquisitionTaxCalculatorTest < ActiveSupport::TestCase
  def setup
    @apartment_id = property_types(:apartment).id
    @officetel_id = property_types(:officetel).id
  end

  test "homeless under 6억 under 85㎡ returns 1.1%" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 50_000,
      property_type_id: @apartment_id,
      household_tier: "homeless",
      regulated_region: false,
      area_over_85: false
    )
    assert_in_delta 0.011, result.rate, 1e-6
    assert_equal 550, result.tax_manwon
  end

  test "homeless 6~9억 under 85㎡ returns 2.2%" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 70_000,
      property_type_id: @apartment_id,
      household_tier: "homeless",
      regulated_region: false,
      area_over_85: false
    )
    assert_in_delta 0.022, result.rate, 1e-6
    assert_equal 1540, result.tax_manwon
  end

  test "homeless 9억+ over 85㎡ returns 3.5%" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 95_000,
      property_type_id: @apartment_id,
      household_tier: "homeless",
      regulated_region: false,
      area_over_85: true
    )
    assert_in_delta 0.035, result.rate, 1e-6
    assert_equal 3325, result.tax_manwon
  end

  test "multi_home_2 regulated region returns 8.4% regardless of bracket" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 40_000,
      property_type_id: @apartment_id,
      household_tier: "multi_home_2",
      regulated_region: true,
      area_over_85: false
    )
    assert_in_delta 0.084, result.rate, 1e-6
    assert_equal 3360, result.tax_manwon
  end

  test "multi_home_3plus regulated returns 12.4%" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 50_000,
      property_type_id: @apartment_id,
      household_tier: "multi_home_3plus",
      regulated_region: true,
      area_over_85: false
    )
    assert_in_delta 0.124, result.rate, 1e-6
    assert_equal 6200, result.tax_manwon
  end

  test "officetel returns 4.6% regardless of inputs" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 100_000,
      property_type_id: @officetel_id,
      household_tier: "homeless",
      regulated_region: false,
      area_over_85: nil
    )
    assert_in_delta 0.046, result.rate, 1e-6
    assert_equal 4600, result.tax_manwon
  end

  test "raises RateNotFoundError when property_type has no rows" do
    stub_pt = PropertyType.create!(code: "stub_unused", name: "stub", enabled: false, sort_order: 99)
    assert_raises(AcquisitionTaxCalculator::RateNotFoundError) do
      AcquisitionTaxCalculator.call(
        bid_manwon: 50_000,
        property_type_id: stub_pt.id,
        household_tier: "homeless",
        regulated_region: false,
        area_over_85: false
      )
    end
  end
end
```

- [ ] **Step 2: Run failing test**

Run: `bin/rails test test/services/acquisition_tax_calculator_test.rb`
Expected: FAIL — `NameError: uninitialized constant AcquisitionTaxCalculator`.

- [ ] **Step 3: Implement the calculator**

```ruby
# app/services/acquisition_tax_calculator.rb
class AcquisitionTaxCalculator
  class RateNotFoundError < StandardError; end

  Result = Data.define(:rate, :tax_manwon, :rate_source)

  def self.call(**kwargs) = new(**kwargs).call

  def initialize(bid_manwon:, property_type_id:, household_tier:,
                 regulated_region:, area_over_85: nil)
    @bid_manwon = bid_manwon.to_i
    @property_type_id = property_type_id
    @household_tier = household_tier
    @regulated_region = regulated_region
    @area_over_85 = area_over_85
  end

  def call
    row = lookup_row
    raise RateNotFoundError, lookup_signature if row.nil?

    rate = row.total_rate.to_d
    Result.new(rate: rate, tax_manwon: (rate * @bid_manwon).round, rate_source: row)
  end

  private

  def lookup_row
    scope = AcquisitionTaxRate
      .where(property_type_id: @property_type_id, household_tier: @household_tier)
      .where("price_bucket_min_manwon <= ?", @bid_manwon)
      .where("price_bucket_max_manwon IS NULL OR price_bucket_max_manwon > ?", @bid_manwon)

    scope = scope.where("regulated_region IS NULL OR regulated_region = ?", @regulated_region)
    scope = scope.where("area_over_85 IS NULL OR area_over_85 = ?", @area_over_85)

    # Prefer concrete matches over NULL (wildcard) ones.
    scope
      .order(Arel.sql("(regulated_region IS NULL), (area_over_85 IS NULL)"))
      .first
  end

  def lookup_signature
    "property_type=#{@property_type_id}, tier=#{@household_tier}, " \
      "bid=#{@bid_manwon}, regulated=#{@regulated_region}, area_over_85=#{@area_over_85}"
  end
end
```

- [ ] **Step 4: Run tests until green**

Run: `bin/rails test test/services/acquisition_tax_calculator_test.rb`
Expected: 7 runs, 0 failures.

- [ ] **Step 5: Commit (behavioral)**

```bash
git add app/services/acquisition_tax_calculator.rb test/services/acquisition_tax_calculator_test.rb
git commit -m "feat(service): add AcquisitionTaxCalculator.call lookup"
```

---

## Task 6: `AcquisitionTaxCalculator.brackets_for` helper (Red → Green)

**Files:**
- Modify: `app/services/acquisition_tax_calculator.rb`
- Modify: `test/services/acquisition_tax_calculator_test.rb`

- [ ] **Step 1: Add failing tests for `.brackets_for`**

Append to `test/services/acquisition_tax_calculator_test.rb`:

```ruby
  test "brackets_for returns ordered brackets for housing single_home under 85㎡ non-regulated" do
    brackets = AcquisitionTaxCalculator.brackets_for(
      property_type_id: @apartment_id,
      household_tier: "homeless",
      regulated_region: false,
      area_over_85: false
    )
    assert_equal 3, brackets.length
    assert_in_delta 0.011, brackets[0][:rate], 1e-6
    assert_equal 60000, brackets[0][:max]
    assert_in_delta 0.022, brackets[1][:rate], 1e-6
    assert_equal 90000, brackets[1][:max]
    assert_in_delta 0.033, brackets[2][:rate], 1e-6
    assert_nil brackets[2][:max]
  end

  test "brackets_for returns a single open-ended bracket for multi_home_3plus regulated" do
    brackets = AcquisitionTaxCalculator.brackets_for(
      property_type_id: @apartment_id,
      household_tier: "multi_home_3plus",
      regulated_region: true,
      area_over_85: false
    )
    assert_equal 1, brackets.length
    assert_in_delta 0.124, brackets[0][:rate], 1e-6
    assert_nil brackets[0][:max]
  end

  test "brackets_for returns single bracket for officetel" do
    brackets = AcquisitionTaxCalculator.brackets_for(
      property_type_id: @officetel_id,
      household_tier: "homeless",
      regulated_region: false,
      area_over_85: nil
    )
    assert_equal 1, brackets.length
    assert_in_delta 0.046, brackets[0][:rate], 1e-6
    assert_nil brackets[0][:max]
  end

  test "brackets_for returns [] for unknown property_type" do
    stub_pt = PropertyType.create!(code: "stub_brackets_empty", name: "stub", enabled: false, sort_order: 99)
    brackets = AcquisitionTaxCalculator.brackets_for(
      property_type_id: stub_pt.id,
      household_tier: "homeless",
      regulated_region: false,
      area_over_85: false
    )
    assert_equal [], brackets
  end
```

- [ ] **Step 2: Run failing tests**

Run: `bin/rails test test/services/acquisition_tax_calculator_test.rb`
Expected: FAIL on the new tests (NoMethodError: undefined method `brackets_for`).

- [ ] **Step 3: Implement `brackets_for`**

Insert at the top of `AcquisitionTaxCalculator` (right after the `Result` line):

```ruby
  def self.brackets_for(property_type_id:, household_tier:,
                        regulated_region:, area_over_85:)
    scope = AcquisitionTaxRate
      .where(property_type_id: property_type_id, household_tier: household_tier)
      .where("regulated_region IS NULL OR regulated_region = ?", regulated_region)
      .where("area_over_85 IS NULL OR area_over_85 = ?", area_over_85)
      .order(:price_bucket_min_manwon)

    scope.map do |row|
      { rate: row.total_rate.to_d, max: row.price_bucket_max_manwon }
    end
  end
```

- [ ] **Step 4: Run tests until green**

Run: `bin/rails test test/services/acquisition_tax_calculator_test.rb`
Expected: 11 runs, 0 failures.

- [ ] **Step 5: Commit (behavioral)**

```bash
git add app/services/acquisition_tax_calculator.rb test/services/acquisition_tax_calculator_test.rb
git commit -m "feat(service): add AcquisitionTaxCalculator.brackets_for"
```

---

## Task 7: `BudgetSetting` validations + helpers for new columns (Red → Green)

**Files:**
- Modify: `app/models/budget_setting.rb`
- Modify: `test/models/budget_setting_test.rb`

- [ ] **Step 1: Add failing tests**

Append to `test/models/budget_setting_test.rb`:

```ruby
  test "household_tier defaults to homeless on new record" do
    bs = BudgetSetting.create!(user: users(:guest), available_cash: 30000)
    assert_equal "homeless", bs.reload.household_tier
  end

  test "household_tier must be in HOUSEHOLD_TIERS" do
    bs = BudgetSetting.new(user: users(:guest), available_cash: 30000, household_tier: "invalid")
    assert_not bs.valid?
    assert_includes bs.errors[:household_tier], "은(는) 목록에 포함되어 있지 않습니다"
  end

  test "acquisition_tax_auto defaults to true on new record" do
    bs = BudgetSetting.create!(user: users(:guest), available_cash: 30000)
    assert_equal true, bs.reload.acquisition_tax_auto
  end

  test "area_over_85? is true when area_range_min >= 85" do
    bs = BudgetSetting.new(area_range_min: 85, area_range_max: 102)
    assert bs.area_over_85?
  end

  test "area_over_85? is false when area_range_min < 85" do
    bs = BudgetSetting.new(area_range_min: 60, area_range_max: 85)
    assert_not bs.area_over_85?
  end

  test "area_over_85? is false when area_range_min is nil" do
    bs = BudgetSetting.new
    assert_not bs.area_over_85?
  end
```

- [ ] **Step 2: Run failing tests**

Run: `bin/rails test test/models/budget_setting_test.rb`
Expected: FAIL on the new tests (`area_over_85?` undefined; household_tier inclusion absent).

- [ ] **Step 3: Update `BudgetSetting`**

Add at the top of the class (after the `belongs_to` lines):

```ruby
  HOUSEHOLD_TIERS = AcquisitionTaxRate::HOUSEHOLD_TIERS
  validates :household_tier, inclusion: { in: HOUSEHOLD_TIERS }
```

Add a public method (near `regulated_region?`):

```ruby
  def area_over_85?
    area_range_min.to_i >= 85
  end
```

- [ ] **Step 4: Run tests until green**

Run: `bin/rails test test/models/budget_setting_test.rb`
Expected: all tests pass (including the previously-existing ones, since `household_tier` has a DB default of `"homeless"`).

- [ ] **Step 5: Commit (behavioral)**

```bash
git add app/models/budget_setting.rb test/models/budget_setting_test.rb
git commit -m "feat(model): household_tier validation and area_over_85? on BudgetSetting"
```

---

## Task 8: `BudgetCalculationService` new signature + bracket iteration (Red → Green)

**Files:**
- Modify: `app/services/budget_calculation_service.rb`
- Modify: `test/services/budget_calculation_service_test.rb`

- [ ] **Step 1: Rewrite the test file**

Replace the contents of `test/services/budget_calculation_service_test.rb` with:

```ruby
require "test_helper"

class BudgetCalculationServiceTest < ActiveSupport::TestCase
  # Single-bucket housing brackets: 6억↓ 1.1%, 6~9억 2.2%, 9억+ 3.3%
  HOUSING_BRACKETS = [
    { rate: 0.011, max: 60_000 },
    { rate: 0.022, max: 90_000 },
    { rate: 0.033, max: nil }
  ].freeze

  test "small-cash scenario picks lowest bracket and yields large bid" do
    result = BudgetCalculationService.call(
      available_cash: 3_000,
      reserves_excluding_acquisition_tax: { repair: 400, scrivener: 60, moving: 100, maintenance: 40 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS
    )

    # R = 600; t1 = 0.011 → B = floor((3000-600)/(0.3+0.011)) = floor(2400/0.311) = 7717
    assert_equal 7717, result[:max_bid_amount]
    assert_equal 85, result[:acquisition_tax]
    assert_in_delta 0.011, result[:acquisition_tax_rate], 1e-6
  end

  test "mid-cash scenario falls through to bracket 2" do
    result = BudgetCalculationService.call(
      available_cash: 30_000,
      reserves_excluding_acquisition_tax: { repair: 800, scrivener: 200, moving: 300, maintenance: 200 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS
    )

    # R = 1500; t1 candidate = floor(28500/0.311) = 91640 > 60000 → t2 candidate = floor(28500/0.322) = 88509
    assert_equal 88_509, result[:max_bid_amount]
    assert_equal 1947, result[:acquisition_tax]
    assert_in_delta 0.022, result[:acquisition_tax_rate], 1e-6
  end

  test "large-cash scenario falls through to bracket 3" do
    result = BudgetCalculationService.call(
      available_cash: 100_000,
      reserves_excluding_acquisition_tax: { repair: 1000, scrivener: 300, moving: 500, maintenance: 200 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS
    )

    # R = 2000; iterates past brackets 1 & 2 → t3 candidate = floor(98000/0.333) = 294294
    assert_equal 294_294, result[:max_bid_amount]
    assert_equal 9712, result[:acquisition_tax]
    assert_in_delta 0.033, result[:acquisition_tax_rate], 1e-6
  end

  test "override mode uses the supplied tax and ignores brackets" do
    result = BudgetCalculationService.call(
      available_cash: 3_000,
      reserves_excluding_acquisition_tax: { repair: 400, scrivener: 60, moving: 100, maintenance: 40 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS,
      acquisition_tax_override: 800
    )

    # B = floor((3000-600-800)/0.3) = floor(1600/0.3) = 5333
    assert_equal 5333, result[:max_bid_amount]
    assert_equal 800, result[:acquisition_tax]
    assert_nil result[:acquisition_tax_rate]
  end

  test "insufficient cash raises InsufficientFundsError" do
    assert_raises(BudgetCalculationService::InsufficientFundsError) do
      BudgetCalculationService.call(
        available_cash: 500,
        reserves_excluding_acquisition_tax: { repair: 400, scrivener: 60, moving: 100, maintenance: 40 },
        loan_ratio: 0.7,
        tax_brackets: HOUSING_BRACKETS
      )
    end
  end

  test "empty tax_brackets in auto mode raises ArgumentError" do
    assert_raises(ArgumentError) do
      BudgetCalculationService.call(
        available_cash: 3_000,
        reserves_excluding_acquisition_tax: { repair: 400, scrivener: 60, moving: 100, maintenance: 40 },
        loan_ratio: 0.7,
        tax_brackets: []
      )
    end
  end

  test "missing reserve items default to zero" do
    result = BudgetCalculationService.call(
      available_cash: 30_000,
      reserves_excluding_acquisition_tax: { repair: 500 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS
    )

    # R = 500; t1 candidate = floor(29500/0.311) = 94855 > 60000 → t2 = floor(29500/0.322) = 91614 > 90000 → t3 = floor(29500/0.333) = 88588
    assert_equal 88_588, result[:max_bid_amount]
    assert_in_delta 0.033, result[:acquisition_tax_rate], 1e-6
  end

  test "breakdown includes all inputs and computed values" do
    result = BudgetCalculationService.call(
      available_cash: 3_000,
      reserves_excluding_acquisition_tax: { repair: 400, scrivener: 60, moving: 100, maintenance: 40 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS
    )

    assert_equal 3_000, result[:breakdown][:available_cash]
    assert_equal 400, result[:breakdown][:repair]
    assert_equal 60, result[:breakdown][:scrivener]
    assert_equal 100, result[:breakdown][:moving]
    assert_equal 40, result[:breakdown][:maintenance]
    assert_equal 85, result[:breakdown][:acquisition_tax]
    assert_equal 0.7, result[:breakdown][:loan_ratio]
    assert_equal 685, result[:total_reserves]
  end
end
```

- [ ] **Step 2: Run failing tests**

Run: `bin/rails test test/services/budget_calculation_service_test.rb`
Expected: FAIL — old service signature uses `reserve_funds:`, not `reserves_excluding_acquisition_tax:` / `tax_brackets:`.

- [ ] **Step 3: Rewrite the service**

Replace the contents of `app/services/budget_calculation_service.rb` with:

```ruby
class BudgetCalculationService
  class InsufficientFundsError < StandardError; end

  RESERVE_KEYS = %i[repair scrivener moving maintenance].freeze

  def self.call(**kwargs) = new(**kwargs).call

  def initialize(available_cash:, reserves_excluding_acquisition_tax:, loan_ratio:,
                 tax_brackets:, acquisition_tax_override: nil)
    @available_cash = available_cash.to_i
    @reserves = reserves_excluding_acquisition_tax
    @loan_ratio = loan_ratio.to_d
    @brackets = tax_brackets
    @override = acquisition_tax_override
  end

  def call
    r = RESERVE_KEYS.sum { |k| @reserves.fetch(k, 0).to_i }

    if @override.nil? && @brackets.empty?
      raise ArgumentError, "tax_brackets must not be empty in auto mode"
    end

    if @override
      tax = @override.to_i
      bid = ((@available_cash - r - tax) / (1 - @loan_ratio)).floor
      rate = nil
    else
      bid, rate = solve_bracket(r)
      tax = (rate * bid).round
    end

    raise InsufficientFundsError if bid <= 0

    Rails.logger.info(
      "[BudgetCalculationService] mode=#{@override ? "override" : "auto"} " \
        "rate=#{rate.inspect} bid=#{bid} tax=#{tax}"
    )

    {
      max_bid_amount: bid,
      acquisition_tax: tax,
      acquisition_tax_rate: rate,
      total_reserves: r + tax,
      breakdown: {
        available_cash: @available_cash,
        repair: @reserves.fetch(:repair, 0).to_i,
        scrivener: @reserves.fetch(:scrivener, 0).to_i,
        moving: @reserves.fetch(:moving, 0).to_i,
        maintenance: @reserves.fetch(:maintenance, 0).to_i,
        acquisition_tax: tax,
        loan_ratio: @loan_ratio.to_f
      }
    }
  end

  private

  def solve_bracket(r)
    @brackets.each do |b|
      rate = b[:rate].to_d
      denom = 1 - @loan_ratio + rate
      candidate = ((@available_cash - r) / denom).floor
      if b[:max].nil? || candidate <= b[:max]
        return [ candidate, rate ]
      end
    end
    raise InsufficientFundsError, "no bracket converged"
  end
end
```

- [ ] **Step 4: Run tests until green**

Run: `bin/rails test test/services/budget_calculation_service_test.rb`
Expected: 8 runs, 0 failures.

- [ ] **Step 5: Commit (behavioral)**

```bash
git add app/services/budget_calculation_service.rb test/services/budget_calculation_service_test.rb
git commit -m "feat(service): bracket-iteration BudgetCalculationService"
```

---

## Task 9: Wire `OnboardingsController#create_step3` to new service

**Files:**
- Modify: `app/controllers/onboardings_controller.rb`
- Modify: `test/controllers/onboardings_controller_test.rb`

- [ ] **Step 1: Add a failing controller test**

Append to `test/controllers/onboardings_controller_test.rb`:

```ruby
  test "create_step3 computes acquisition_tax via bracket iteration in auto mode" do
    setting = users(:guest).build_budget_setting(
      available_cash: 3_000,
      property_type: property_types(:apartment),
      area_range_min: 0, area_range_max: 40,
      household_tier: "homeless",
      acquisition_tax_auto: true,
      repair_cost: 400, scrivener_fee: 60, moving_cost: 100, maintenance_fee: 40,
      loan_policy: loan_policies(:auction_bank_apartment),
      region: "경기도"
    )
    setting.save!

    post step3_onboarding_url, params: { budget_setting: { loan_policy_id: setting.loan_policy_id, loan_ratio: 0.7 } }

    assert_response :redirect
    setting.reload
    assert_equal 7717, setting.max_bid_amount
    assert_equal 85, setting.acquisition_tax
  end

  test "create_step3 respects override mode" do
    setting = users(:guest).build_budget_setting(
      available_cash: 3_000,
      property_type: property_types(:apartment),
      area_range_min: 0, area_range_max: 40,
      household_tier: "homeless",
      acquisition_tax_auto: false,
      acquisition_tax: 800,
      repair_cost: 400, scrivener_fee: 60, moving_cost: 100, maintenance_fee: 40,
      loan_policy: loan_policies(:auction_bank_apartment),
      region: "경기도"
    )
    setting.save!

    post step3_onboarding_url, params: { budget_setting: { loan_policy_id: setting.loan_policy_id, loan_ratio: 0.7 } }

    assert_response :redirect
    setting.reload
    assert_equal 5333, setting.max_bid_amount
    assert_equal 800, setting.acquisition_tax
  end
```

- [ ] **Step 2: Run failing test**

Run: `bin/rails test test/controllers/onboardings_controller_test.rb`
Expected: FAIL — existing controller still calls old service signature; raises `ArgumentError`.

- [ ] **Step 3: Update the controller**

Edit `app/controllers/onboardings_controller.rb`:

Replace the `create_step3` body (the existing service call block) with:

```ruby
  def create_step3
    @setting.assign_attributes(step3_params)

    unless @setting.available_cash.present?
      redirect_to start_onboarding_url
      return
    end

    brackets = AcquisitionTaxCalculator.brackets_for(
      property_type_id: @setting.property_type_id,
      household_tier: @setting.household_tier,
      regulated_region: @setting.regulated_region?,
      area_over_85: @setting.area_over_85?
    )

    result = BudgetCalculationService.call(
      available_cash: @setting.available_cash,
      reserves_excluding_acquisition_tax: {
        repair: @setting.repair_cost.to_i,
        scrivener: @setting.scrivener_fee.to_i,
        moving: @setting.moving_cost.to_i,
        maintenance: @setting.maintenance_fee.to_i
      },
      loan_ratio: @setting.loan_ratio.to_f,
      tax_brackets: brackets,
      acquisition_tax_override: @setting.acquisition_tax_auto? ? nil : @setting.acquisition_tax.to_i
    )

    @setting.acquisition_tax = result[:acquisition_tax] if @setting.acquisition_tax_auto?
    @setting.max_bid_amount = result[:max_bid_amount]
    @setting.completed_at = Time.current

    if @setting.save
      redirect_to complete_onboarding_url
    else
      load_step3_data
      render :step3, status: :unprocessable_entity
    end
  rescue BudgetCalculationService::InsufficientFundsError, ArgumentError
    @setting.errors.add(:available_cash, "이(가) 예비비 합계보다 작습니다")
    load_step3_data
    render :step3, status: :unprocessable_entity
  end
```

Update `step2_params` and `step3_params` to permit the new fields:

```ruby
  def step2_params
    params.expect(budget_setting: [
      :property_type_id, :area_category,
      :household_tier, :acquisition_tax_auto,
      :repair_cost, :acquisition_tax, :scrivener_fee, :moving_cost, :maintenance_fee
    ])
  end
```

- [ ] **Step 4: Run tests until green**

Run: `bin/rails test test/controllers/onboardings_controller_test.rb`
Expected: all tests pass (new + existing).

- [ ] **Step 5: Commit (behavioral)**

```bash
git add app/controllers/onboardings_controller.rb test/controllers/onboardings_controller_test.rb
git commit -m "feat(onboarding): wire bracket-iteration service in create_step3"
```

---

## Task 10: Wire `Settings::BudgetsController#update` to new service

**Files:**
- Modify: `app/controllers/settings/budgets_controller.rb`
- Modify: `test/controllers/settings/budgets_controller_test.rb` (if it exists; otherwise create)

- [ ] **Step 1: Check if a controller test exists**

Run: `ls test/controllers/settings/budgets_controller_test.rb 2>/dev/null && echo PRESENT || echo MISSING`
If MISSING, create a minimal file:

```ruby
# test/controllers/settings/budgets_controller_test.rb
require "test_helper"

class Settings::BudgetsControllerTest < ActionDispatch::IntegrationTest
end
```

- [ ] **Step 2: Add a failing test for the auto-mode update path**

Append to the test class:

```ruby
  test "PATCH update recalculates acquisition_tax in auto mode" do
    setting = users(:guest).build_budget_setting(
      available_cash: 3_000,
      property_type: property_types(:apartment),
      area_range_min: 0, area_range_max: 40,
      household_tier: "homeless",
      acquisition_tax_auto: true,
      repair_cost: 400, acquisition_tax: 9999,
      scrivener_fee: 60, moving_cost: 100, maintenance_fee: 40,
      loan_policy: loan_policies(:auction_bank_apartment),
      loan_ratio: 0.7,
      region: "경기도",
      max_bid_amount: 1,
      completed_at: Time.current
    )
    setting.save!

    patch settings_budget_url, params: { budget_setting: {
      available_cash: 3_000,
      property_type_id: property_types(:apartment).id,
      area_category: "small",
      household_tier: "homeless",
      acquisition_tax_auto: "1",
      acquisition_tax: "9999",            # should be overwritten by auto
      repair_cost: "400", scrivener_fee: "60", moving_cost: "100", maintenance_fee: "40",
      loan_policy_id: loan_policies(:auction_bank_apartment).id,
      loan_ratio: "0.7",
      region: "경기도"
    } }

    assert_response :redirect
    setting.reload
    assert_equal 7717, setting.max_bid_amount
    assert_equal 85, setting.acquisition_tax
  end
```

- [ ] **Step 3: Run failing test**

Run: `bin/rails test test/controllers/settings/budgets_controller_test.rb`
Expected: FAIL.

- [ ] **Step 4: Update the controller**

In `app/controllers/settings/budgets_controller.rb`, replace the body between `@setting.area_range_max = range[:max] if range[:max]` and `if @setting.save` with:

```ruby
      unless @setting.valid?
        load_show_data
        render :show, status: :unprocessable_entity
        return
      end

      brackets = AcquisitionTaxCalculator.brackets_for(
        property_type_id: @setting.property_type_id,
        household_tier: @setting.household_tier,
        regulated_region: @setting.regulated_region?,
        area_over_85: @setting.area_over_85?
      )

      result = BudgetCalculationService.call(
        available_cash: @setting.available_cash,
        reserves_excluding_acquisition_tax: {
          repair: @setting.repair_cost.to_i,
          scrivener: @setting.scrivener_fee.to_i,
          moving: @setting.moving_cost.to_i,
          maintenance: @setting.maintenance_fee.to_i
        },
        loan_ratio: @setting.loan_ratio.to_f,
        tax_brackets: brackets,
        acquisition_tax_override: @setting.acquisition_tax_auto? ? nil : @setting.acquisition_tax.to_i
      )

      @setting.acquisition_tax = result[:acquisition_tax] if @setting.acquisition_tax_auto?
      @setting.max_bid_amount = result[:max_bid_amount]
```

(Delete the previous `valid?` block and the old `BudgetCalculationService.call(...)` block.)

Update `budget_params` to permit the new fields:

```ruby
    def budget_params
      params.expect(budget_setting: [
        :available_cash, :property_type_id, :area_category,
        :household_tier, :acquisition_tax_auto,
        :repair_cost, :acquisition_tax, :scrivener_fee,
        :moving_cost, :maintenance_fee, :loan_policy_id, :loan_ratio,
        :region
      ])
    end
```

Add the same rescue clause for `ArgumentError` to the existing rescue line:

```ruby
    rescue BudgetCalculationService::InsufficientFundsError, ArgumentError
```

- [ ] **Step 5: Run tests until green**

Run: `bin/rails test test/controllers/settings/budgets_controller_test.rb`
Expected: passes.

- [ ] **Step 6: Commit (behavioral)**

```bash
git add app/controllers/settings/budgets_controller.rb test/controllers/settings/budgets_controller_test.rb
git commit -m "feat(budget-settings): wire bracket-iteration service in update"
```

---

## Task 11: UI — onboarding step2 (household_tier dropdown + readonly auto)

**Files:**
- Modify: `app/views/onboardings/step2.html.erb`
- Modify: `app/controllers/onboardings_controller.rb` (pass brackets and current tax preview to view)

- [ ] **Step 1: Update controller to expose data for the view**

In `app/controllers/onboardings_controller.rb`, modify `load_step2_data` to compute and assign `@tax_brackets` and `@household_tier_options`:

```ruby
  def load_step2_data
    @property_types = PropertyType.enabled.ordered
    @reserve_defaults = ReserveFundDefault.where(
      property_type_id: @property_types.pluck(:id)
    ).group_by(&:property_type_id)
    apply_step2_defaults
    @household_tier_options = [
      [ "무주택 (현재 집이 없거나 곧 처분)", "homeless" ],
      [ "1주택 (현재 1채 보유)",          "single_home" ],
      [ "2주택 보유",                     "multi_home_2" ],
      [ "3주택 이상",                     "multi_home_3plus" ]
    ]
    @tax_brackets = AcquisitionTaxCalculator.brackets_for(
      property_type_id: @setting.property_type_id,
      household_tier: @setting.household_tier,
      regulated_region: @setting.regulated_region?,
      area_over_85: @setting.area_over_85?
    )
  end
```

- [ ] **Step 2: Update `app/views/onboardings/step2.html.erb`**

Find the `<%# 관심 면적 %>` block (around line 22). Immediately after that block's closing `</div>`, insert:

```erb
        <%# 주택 보유 상태 %>
        <div class="mb-4">
          <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">
            <span class="relative inline-flex items-center gap-1 cursor-help"
                  data-controller="tooltip"
                  data-tooltip-content-value="주택 수가 많을수록 취득세율이 높아집니다 (조정대상지역 2주택 8.4%, 3주택+ 12.4%)"
                  data-action="mouseenter->tooltip#show mouseleave->tooltip#hide">
              주택 보유
              <svg class="inline w-3.5 h-3.5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
              </svg>
            </span>
          </label>
          <%= f.select :household_tier, @household_tier_options,
            {},
            { class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500",
              data: { reserve_fund_target: "householdTier",
                      action: "change->reserve-fund#householdTierChanged" } } %>
        </div>
```

Add a `data-reserve-fund-tax-brackets-value` and `data-reserve-fund-loan-ratio-value` attribute to the `<div data-controller="reserve-fund" ...>` opener (line 8):

```erb
    <div data-controller="reserve-fund"
         data-reserve-fund-defaults-value="<%= @reserve_defaults.to_json %>"
         data-reserve-fund-available-cash-value="<%= @setting.available_cash.to_i %>"
         data-reserve-fund-tax-brackets-value="<%= @tax_brackets.to_json %>"
         data-reserve-fund-loan-ratio-value="<%= @setting.loan_ratio.to_f.zero? ? 0.7 : @setting.loan_ratio.to_f %>"
         data-reserve-fund-acquisition-tax-auto-value="<%= @setting.acquisition_tax_auto %>">
```

Find the acquisition_tax input (the row for `:acquisition_tax` in the iteration around line 47) and add a hidden field for `acquisition_tax_auto` plus update its hint target. The change set:

(a) Just BEFORE the `<div class="space-y-3">` block at line 46, insert:

```erb
        <%# Hidden auto flag — Stimulus toggles to match autoCalc checkbox %>
        <%= f.hidden_field :acquisition_tax_auto, value: @setting.acquisition_tax_auto, data: { reserve_fund_target: "acquisitionTaxAuto" } %>
```

(b) The acquisition_tax row's input — add `data-reserve-fund-readonly-when-auto="true"`:

```erb
                <%= f.number_field field, inputmode: "numeric",
                  class: "flex-1 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500",
                  data: {
                    reserve_fund_target: target,
                    reserve_fund_readonly_when_auto: (field == :acquisition_tax).to_s,
                    action: "input->reserve-fund#updateTotal"
                  } %>
```

- [ ] **Step 3: Add to controller permitted params** (already done in Task 9 step 3, double-check)

`step2_params` already includes `:household_tier`, `:acquisition_tax_auto`. Confirm with: `grep household_tier app/controllers/onboardings_controller.rb`.

- [ ] **Step 4: Manual smoke check (no JS yet — readonly applied via JS in Task 13)**

Run: `bin/rails server` (in another shell), then visit `http://localhost:3000/onboarding/step2`.
Expected: 주택 보유 dropdown visible with "무주택…" selected. No JS errors in console (acquisition_tax input is still editable — that's wired in Task 13).

- [ ] **Step 5: Commit (structural — view + controller plumbing)**

```bash
git add app/views/onboardings/step2.html.erb app/controllers/onboardings_controller.rb
git commit -m "feat(onboarding-ui): add household_tier dropdown and tax brackets to step2"
```

---

## Task 12: UI — `/settings/budget` show + onboarding complete

**Files:**
- Modify: `app/views/settings/budgets/show.html.erb`
- Modify: `app/views/onboardings/complete.html.erb`
- Modify: `app/controllers/settings/budgets_controller.rb`

- [ ] **Step 1: Expose `@tax_brackets` and `@household_tier_options` from `Settings::BudgetsController`**

In `app/controllers/settings/budgets_controller.rb`, modify `load_show_data` to append:

```ruby
      @household_tier_options = [
        [ "무주택 (현재 집이 없거나 곧 처분)", "homeless" ],
        [ "1주택 (현재 1채 보유)",          "single_home" ],
        [ "2주택 보유",                     "multi_home_2" ],
        [ "3주택 이상",                     "multi_home_3plus" ]
      ]
      @tax_brackets = AcquisitionTaxCalculator.brackets_for(
        property_type_id: @setting.property_type_id,
        household_tier: @setting.household_tier,
        regulated_region: @setting.regulated_region?,
        area_over_85: @setting.area_over_85?
      )
```

- [ ] **Step 2: Mirror the step2 UI changes in `app/views/settings/budgets/show.html.erb`**

(a) Add the same `data-reserve-fund-*-value` attributes to the outer `data-controller="reserve-fund"` div.

(b) Insert a 주택 보유 dropdown right after the property-type / area-category block (matching position to step2).

(c) Add `data-reserve-fund-readonly-when-auto="true"` to the acquisition_tax row's input.

(d) Add the hidden `acquisition_tax_auto` field before the reserve loop.

Use the same ERB snippets shown in Task 11 Step 2, but adjusted for this view's form helper (`f`). The class structures match.

- [ ] **Step 3: Update `app/views/onboardings/complete.html.erb`**

The 취득세 row is rendered through `SummaryTableComponent`. Rather than extending that component's interface, add the basis line as a standalone paragraph **immediately after** the `SummaryTableComponent` block (after the closing `</div>` on the line containing `<% ) %>`, before the `<p class="text-sm text-slate-400 ...">적용 정책: ...</p>` paragraph).

Insert:

```erb
    <% if (line = tax_basis_line(@setting)) %>
      <p class="text-xs text-slate-500 dark:text-slate-400 text-center mt-2"><%= line %></p>
    <% end %>
```

(`tax_basis_line` is the view helper defined in Step 4.)

- [ ] **Step 4: Define `tax_basis_line` helper**

Append to `app/helpers/application_helper.rb` (or appropriate helper file):

```ruby
  def tax_basis_line(setting)
    return nil unless setting.acquisition_tax_auto?
    return nil if setting.max_bid_amount.to_i.zero? || setting.acquisition_tax.to_i.zero?

    rate = (setting.acquisition_tax.to_d / setting.max_bid_amount.to_d * 100).round(1)
    tier_label = {
      "homeless" => "1세대 무주택",
      "single_home" => "1주택",
      "multi_home_2" => "2주택",
      "multi_home_3plus" => "3주택 이상"
    }.fetch(setting.household_tier, "")
    area_label = setting.area_over_85? ? "전용 85㎡ 초과" : "전용 85㎡ 이하"

    "낙찰가 #{number_with_delimiter(setting.max_bid_amount)}만원 × #{rate}% = " \
      "#{number_with_delimiter(setting.acquisition_tax)}만원 (#{tier_label}, #{area_label})"
  end
```

- [ ] **Step 5: Manual smoke check**

Run: `bin/rails server`, then visit `/settings/budget` and `/onboarding/complete` after completing the onboarding flow.
Expected: 주택 보유 dropdown visible on settings, basis line visible on complete page.

- [ ] **Step 6: Commit (structural)**

```bash
git add app/views/settings/budgets/show.html.erb app/views/onboardings/complete.html.erb app/controllers/settings/budgets_controller.rb app/helpers/application_helper.rb
git commit -m "feat(ui): expose household_tier and tax basis on settings and complete pages"
```

---

## Task 13: Stimulus `reserve_fund_controller.js` — client-side bracket iteration

**Files:**
- Modify: `app/javascript/controllers/reserve_fund_controller.js`

- [ ] **Step 1: Replace `applyDefaults()` and add `computeAuto()`**

Open `app/javascript/controllers/reserve_fund_controller.js`. Update the `static targets` list to add `householdTier` and `acquisitionTaxAuto`:

```js
  static targets = [
    "autoCalc", "propertyType",
    "areaCategory", "householdTier", "acquisitionTaxAuto",
    "repairCost", "acquisitionTax", "scrivenerFee",
    "movingCost", "maintenanceFee", "total",
    "repairCostHint", "acquisitionTaxHint", "scrivenerFeeHint",
    "movingCostHint", "maintenanceFeeHint",
    "summaryBox", "warning", "submitBtn"
  ]
```

Update `static values`:

```js
  static values = {
    defaults: Object,
    availableCash: { type: Number, default: 0 },
    taxBrackets: { type: Array, default: [] },
    loanRatio: { type: Number, default: 0.7 }
  }
```

Replace the call site at line 79 (which currently does `Math.round(match.acquisition_tax_rate * match.average_price)`) with:

```js
      this.repairCostTarget.value = match.repair_cost
      this.acquisitionTaxTarget.value = this.computeAuto()
      this.scrivenerFeeTarget.value = match.scrivener_fee
```

Add the new method anywhere in the class (e.g., before `updateHints`):

```js
  // Closed-form bracket iteration mirroring BudgetCalculationService.
  // Returns acquisition tax in 만원 (integer).
  computeAuto() {
    const cash = this.availableCashValue
    const loanRatio = this.loanRatioValue
    const brackets = this.taxBracketsValue

    if (!brackets || brackets.length === 0) return 0

    const reserveExclTax = [
      this.repairCostTarget, this.scrivenerFeeTarget,
      this.movingCostTarget, this.maintenanceFeeTarget
    ].reduce((sum, f) => sum + (parseInt(String(f.value).replace(/,/g, ""), 10) || 0), 0)

    if (cash - reserveExclTax <= 0) return 0

    for (const b of brackets) {
      const rate = parseFloat(b.rate)
      const denom = 1 - loanRatio + rate
      const candidate = Math.floor((cash - reserveExclTax) / denom)
      if (b.max == null || candidate <= b.max) {
        return Math.round(rate * candidate)
      }
    }
    return 0
  }

  householdTierChanged() {
    // Brackets are pre-serialized per current setting; when the tier changes,
    // we re-fetch them via a tiny endpoint to stay accurate without a full reload.
    // YAGNI for V1: just recompute total — server will recalc on submit anyway.
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.acquisitionTaxTarget.value = this.computeAuto()
    }
    this.updateTotal()
  }
```

Update `toggleAutoCalc` so the readonly attribute on the acquisition_tax input flips with the checkbox:

```js
  toggleAutoCalc() {
    const auto = this.autoCalcTarget.checked
    if (this.hasAcquisitionTaxAutoTarget) this.acquisitionTaxAutoTarget.value = auto ? "true" : "false"
    this.acquisitionTaxTarget.readOnly = auto
    this.acquisitionTaxTarget.classList.toggle("bg-slate-100", auto)
    if (auto) {
      this.acquisitionTaxTarget.value = this.computeAuto()
      this.applyDefaults()
    }
    this.updateTotal()
  }
```

Update `connect()` to set the initial readonly state:

```js
  connect() {
    if (this.hasAcquisitionTaxTarget && this.hasAutoCalcTarget) {
      this.acquisitionTaxTarget.readOnly = this.autoCalcTarget.checked
      this.acquisitionTaxTarget.classList.toggle("bg-slate-100", this.autoCalcTarget.checked)
    }
    this.updateTotal()
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked) {
      this.applyDefaults()
    }
  }
```

Update `updateHints(match)` — replace the acquisition_tax hint line:

```js
    if (this.hasAcquisitionTaxHintTarget) {
      const tax = this.computeAuto()
      this.acquisitionTaxHintTarget.textContent = `예상 낙찰가 기반 ${tax.toLocaleString("ko-KR")}만원`
    }
```

Make the running total trigger `computeAuto()` when reserves change so the acquisition_tax field stays in sync:

In `updateTotal()`, at the top, add:

```js
    if (this.hasAutoCalcTarget && this.autoCalcTarget.checked && this.hasAcquisitionTaxTarget) {
      this.acquisitionTaxTarget.value = this.computeAuto()
    }
```

- [ ] **Step 2: Manual smoke test**

Run: `bin/rails server`.
Visit `/onboarding/step2`. Verify:
- 취득세 input is readonly when 자동 계산 checked
- Toggling 자동 계산 unchecks → input becomes editable
- Changing 주택 보유 dropdown updates the displayed 취득세 value via the next submit (server-side authoritative; client may not recompute brackets without an AJAX call, which is acceptable for V1 per spec — value will be correct after submit)
- Changing repair_cost, scrivener_fee, etc. with 자동 ON recomputes 취득세 live

- [ ] **Step 3: Commit (behavioral)**

```bash
git add app/javascript/controllers/reserve_fund_controller.js
git commit -m "feat(reserve-fund-js): client-side bracket iteration and readonly auto mode"
```

---

## Task 14: System test — small-property regression

**Files:**
- Create: `test/system/c4_small_property_regression_test.rb`

- [ ] **Step 1: Write the failing system test**

```ruby
# test/system/c4_small_property_regression_test.rb
require "application_system_test_case"

class C4SmallPropertyRegressionTest < ApplicationSystemTestCase
  test "small-cash user can complete onboarding without acquisition tax blocking" do
    visit start_onboarding_path

    fill_in "쓸 수 있는 현금", with: "3000"
    select "경기도", from: "관심 지역"
    click_on "다음"

    # Step 2 — confirm 주택 보유 dropdown defaults to 무주택
    assert_select "select[name='budget_setting[household_tier]']" do |els|
      assert_includes els.first.value, "homeless"
    end
    click_on "다음"

    # Step 3 — pick a loan policy and submit
    select "70%", from: "대출 비율"
    click_on "완료"

    # The bug being fixed: acquisition_tax was 528만원 (4.8억 × 1.1%)
    # which made max_bid_amount drop to ~6,500만원 minus the inflated reserve.
    # After fix: acquisition_tax should be < 200만원, max_bid >= 7,500만원.
    bs = User.find_by!(email: "guest@auction.local").budget_setting
    assert_operator bs.acquisition_tax, :<, 200, "acquisition_tax should be small for a 3,000만원 cash scenario"
    assert_operator bs.max_bid_amount, :>=, 7_500, "max_bid_amount should not be artificially depressed by inflated tax"
  end
end
```

- [ ] **Step 2: Run failing test (skip if no system test infrastructure)**

Run: `bin/rails test:system test/system/c4_small_property_regression_test.rb`
Expected: PASS (assuming Tasks 1-13 completed). If it fails on selector mismatches, adjust the labels above to match the real ERB.

If system tests are not configured to run headlessly in this environment, mark this test as `skip` with a note and rely on the controller test in Task 9 for regression coverage.

- [ ] **Step 3: Commit (behavioral)**

```bash
git add test/system/c4_small_property_regression_test.rb
git commit -m "test(system): lock C-4 small-property regression"
```

---

## Task 15: Full test suite verification

- [ ] **Step 1: Run all tests**

Run: `bin/rails test`
Expected: all tests pass. If any fixture-related tests fail due to the new `household_tier` column, fix the affected fixtures (`test/fixtures/budget_settings.yml` if present) by adding `household_tier: homeless` to each row.

- [ ] **Step 2: Run system tests separately**

Run: `bin/rails test:system`
Expected: passes (or all `skip`ed if system tests are not configured).

- [ ] **Step 3: Manual end-to-end walk-through**

Run: `bin/rails server` and exercise:
1. Fresh onboarding from `/start` → step1 → step2 → step3 → complete. Verify the 취득세 산출 근거 line appears on complete.
2. `/settings/budget`: change 주택 보유 from 무주택 to 3주택 이상 → submit → 취득세 jumps significantly higher; max_bid_amount drops accordingly.
3. `/settings/budget`: uncheck 자동 계산 → input becomes editable → set 취득세 to 1500 → submit → value persists.
4. Console (browser DevTools): no JS errors during any of the above.

- [ ] **Step 4: If anything is broken, fix it and commit small follow-up patches**

Each fix = its own commit, with a clear message describing what the test caught.

---

## Self-Review Checklist

Spec coverage check (each spec section → which task implements it):

- §3 Formula → Tasks 8 (service), 13 (JS mirror)
- §4 Data Model → Tasks 1, 2, 3
- §5 Service Layer → Tasks 5, 6, 8
- §6 UI Surfaces → Tasks 11, 12, 13
- §7 Error Handling → Task 8 (ArgumentError on empty brackets), Tasks 9 & 10 (controller rescues)
- §8 Testing Strategy → Tasks 4, 5, 6, 7, 8, 9, 10, 14
- §9 Commit Sequence → all tasks split structural vs. behavioral
- §10 Follow-ups → out of scope (separate PRs)
- §11 Observability → Task 8 `Rails.logger.info` line

Placeholder scan: none — every code block is concrete.

Type consistency check:
- `Result = Data.define(:rate, :tax_manwon, :rate_source)` used in Task 5 → consumed by `result.rate` / `result.tax_manwon` in tests (matching field names).
- `brackets_for` returns `[{ rate:, max: }]` symbol-keyed hashes throughout (Task 6 impl, Task 8 tests, Task 11/13 JS consumer reads `b.rate` and `b.max` via JSON; JSON serialization preserves string keys so the JS reads `b.rate` and `b.max` — verify in Task 13). 
  - **Adjustment:** Ruby symbol keys serialize to string keys in JSON. The JS in Task 13 already accesses `b.rate` / `b.max`, which works regardless. OK.
- Controller wiring uses `acquisition_tax_override:` (Tasks 9, 10) — matches the service kwarg in Task 8.
- `area_over_85?` defined in Task 7 → consumed in Tasks 9, 10, 11, 12.

---

## Execution Choice

Plan complete and saved to `docs/superpowers/plans/2026-05-12-c4-acquisition-tax-redesign.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
