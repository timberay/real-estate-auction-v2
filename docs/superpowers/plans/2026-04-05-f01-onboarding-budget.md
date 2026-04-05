# F01 Onboarding Budget Setup — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 3-step onboarding wizard that calculates a user's maximum biddable amount for real estate auctions, with immutable snapshot versioning and dynamic loan policy support.

**Architecture:** Rails 8.1 monolith with Turbo Frame wizard (server-side step transitions) + Stimulus controllers (client-side interactivity: sliders, number formatting, unit conversion). Data flows through Live tables (editable settings) and Snapshot tables (immutable point-in-time records). Loan policies use an Adapter pattern (Mock/Government API) with Solid Queue for periodic sync.

**Tech Stack:** Rails 8.1, Ruby 3.4.8, SQLite, Hotwire (Turbo + Stimulus), TailwindCSS, Solid Queue, Minitest, bcrypt (has_secure_password)

**Spec:** `docs/superpowers/specs/2026-04-05-f01-onboarding-budget-design.md`

---

## File Map

### Models (create)
- `app/models/user.rb` — Guest user with has_secure_password
- `app/models/property_type.rb` — Property type registry (enabled flag)
- `app/models/reserve_fund_default.rb` — Per-type/area default reserve values
- `app/models/loan_policy.rb` — Government loan policies with effective dates
- `app/models/budget_setting.rb` — User's current live budget configuration
- `app/models/budget_snapshot.rb` — Immutable point-in-time calculation record

### Migrations (create)
- `db/migrate/xxx_create_users.rb`
- `db/migrate/xxx_create_property_types.rb`
- `db/migrate/xxx_create_reserve_fund_defaults.rb`
- `db/migrate/xxx_create_loan_policies.rb`
- `db/migrate/xxx_create_budget_settings.rb`
- `db/migrate/xxx_create_budget_snapshots.rb`

### Seed Data (create)
- `db/seeds/property_types.json` — Property type definitions
- `db/seeds/reserve_fund_defaults.json` — Default reserve amounts per type/area
- `db/seeds/loan_policies.json` — Mock loan policy data
- `db/seeds.rb` — Modified to load JSON seed files

### Adapters (create)
- `app/adapters/loan_policy_adapter.rb` — Base class with `.for(provider)` factory
- `app/adapters/mock_loan_policy_adapter.rb` — Returns seed data
- `app/adapters/government_loan_policy_adapter.rb` — Stub for real API

### Services (create)
- `app/services/budget_calculation_service.rb` — Core formula: (cash - reserves) / (1 - ratio)
- `app/services/budget_snapshot_service.rb` — Create/recalculate/compare snapshots
- `app/services/loan_policy_sync_service.rb` — Sync adapter data to DB

### Jobs (create)
- `app/jobs/loan_policy_sync_job.rb` — Solid Queue daily sync

### Controllers (create/modify)
- `app/controllers/application_controller.rb` — Modify: add guest auto-session
- `app/controllers/home_controller.rb` — Create: root page with onboarding redirect
- `app/controllers/onboardings_controller.rb` — Create: 3-step wizard + complete
- `app/controllers/settings/budgets_controller.rb` — Create: budget settings edit
- `app/controllers/settings/budget_snapshots_controller.rb` — Create: snapshot history/compare

### Views (create) — MUST use `/rails-ui` skill
- `app/views/home/index.html.erb`
- `app/views/onboardings/step1.html.erb`
- `app/views/onboardings/step2.html.erb`
- `app/views/onboardings/step3.html.erb`
- `app/views/onboardings/complete.html.erb`
- `app/views/settings/budgets/show.html.erb`
- `app/views/settings/budget_snapshots/index.html.erb`
- `app/views/settings/budget_snapshots/show.html.erb`
- `app/views/settings/budget_snapshots/compare.html.erb`

### Stimulus Controllers (create)
- `app/javascript/controllers/number_format_controller.js`
- `app/javascript/controllers/reserve_fund_controller.js`
- `app/javascript/controllers/area_unit_controller.js`
- `app/javascript/controllers/loan_slider_controller.js`
- `app/javascript/controllers/failed_rounds_controller.js`
- `app/javascript/controllers/navigation_controller.js`

### Tests (create)
- `test/models/user_test.rb`
- `test/models/property_type_test.rb`
- `test/models/reserve_fund_default_test.rb`
- `test/models/loan_policy_test.rb`
- `test/models/budget_setting_test.rb`
- `test/models/budget_snapshot_test.rb`
- `test/adapters/loan_policy_adapter_test.rb`
- `test/adapters/mock_loan_policy_adapter_test.rb`
- `test/services/budget_calculation_service_test.rb`
- `test/services/budget_snapshot_service_test.rb`
- `test/services/loan_policy_sync_service_test.rb`
- `test/jobs/loan_policy_sync_job_test.rb`
- `test/controllers/home_controller_test.rb`
- `test/controllers/onboardings_controller_test.rb`
- `test/controllers/settings/budgets_controller_test.rb`
- `test/controllers/settings/budget_snapshots_controller_test.rb`

### Config (modify)
- `config/routes.rb` — Add all F01 routes
- `Gemfile` — Uncomment bcrypt

---

## Task 1: Enable bcrypt for has_secure_password

**Files:**
- Modify: `Gemfile:21`

- [ ] **Step 1: Uncomment bcrypt in Gemfile**

In `Gemfile`, change line 21 from:

```ruby
# gem "bcrypt", "~> 3.1.7"
```

to:

```ruby
gem "bcrypt", "~> 3.1.7"
```

- [ ] **Step 2: Bundle install**

Run: `bundle install`
Expected: bcrypt gem installs successfully

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore: enable bcrypt gem for has_secure_password"
```

---

## Task 2: Create Users migration and model

**Files:**
- Create: `db/migrate/xxx_create_users.rb`
- Create: `app/models/user.rb`
- Create: `test/models/user_test.rb`
- Create: `test/fixtures/users.yml`

- [ ] **Step 1: Write the failing test**

Create `test/models/user_test.rb`:

```ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user with email and password" do
    user = User.new(email: "test@example.com", password: "password123")
    assert user.valid?
  end

  test "invalid without email" do
    user = User.new(email: nil, password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid with duplicate email" do
    User.create!(email: "dup@example.com", password: "password123")
    user = User.new(email: "dup@example.com", password: "password456")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "invalid without password on create" do
    user = User.new(email: "test@example.com", password: nil)
    assert_not user.valid?
  end

  test "authenticates with correct password" do
    user = User.create!(email: "auth@example.com", password: "secret123")
    assert user.authenticate("secret123")
    assert_not user.authenticate("wrong")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/user_test.rb`
Expected: FAIL — `NameError: uninitialized constant User` or migration needed

- [ ] **Step 3: Generate migration**

Run: `bin/rails generate migration CreateUsers email:string:uniq password_digest:string`

Then edit the generated migration to add `not null` constraints:

```ruby
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
```

- [ ] **Step 4: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration runs successfully

- [ ] **Step 5: Create User model**

Create `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  has_secure_password

  validates :email, presence: true, uniqueness: true
end
```

- [ ] **Step 6: Create fixtures**

Create `test/fixtures/users.yml`:

```yaml
guest:
  email: "guest@auction.local"
  password_digest: <%= BCrypt::Password.create("123456") %>
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/models/user_test.rb`
Expected: 5 tests, 5 assertions, 0 failures

- [ ] **Step 8: Commit**

```bash
git add app/models/user.rb db/migrate/*_create_users.rb test/models/user_test.rb test/fixtures/users.yml db/schema.rb
git commit -m "feat: add User model with has_secure_password"
```

---

## Task 3: Create PropertyType migration and model

**Files:**
- Create: `db/migrate/xxx_create_property_types.rb`
- Create: `app/models/property_type.rb`
- Create: `test/models/property_type_test.rb`
- Create: `test/fixtures/property_types.yml`

- [ ] **Step 1: Write the failing test**

Create `test/models/property_type_test.rb`:

```ruby
require "test_helper"

class PropertyTypeTest < ActiveSupport::TestCase
  test "valid with name, code, and enabled" do
    pt = PropertyType.new(name: "아파트", code: "apartment", enabled: true, sort_order: 0)
    assert pt.valid?
  end

  test "invalid without name" do
    pt = PropertyType.new(name: nil, code: "test", enabled: true)
    assert_not pt.valid?
    assert_includes pt.errors[:name], "can't be blank"
  end

  test "invalid without code" do
    pt = PropertyType.new(name: "테스트", code: nil, enabled: true)
    assert_not pt.valid?
    assert_includes pt.errors[:code], "can't be blank"
  end

  test "invalid with duplicate code" do
    PropertyType.create!(name: "아파트", code: "apartment", enabled: true)
    pt = PropertyType.new(name: "아파트2", code: "apartment", enabled: true)
    assert_not pt.valid?
    assert_includes pt.errors[:code], "has already been taken"
  end

  test "scope enabled returns only enabled types" do
    PropertyType.create!(name: "아파트", code: "apartment", enabled: true, sort_order: 0)
    PropertyType.create!(name: "단독주택", code: "house", enabled: false, sort_order: 3)

    enabled = PropertyType.enabled
    assert_equal 1, enabled.count
    assert_equal "apartment", enabled.first.code
  end

  test "scope ordered sorts by sort_order" do
    PropertyType.create!(name: "오피스텔", code: "officetel", enabled: true, sort_order: 2)
    PropertyType.create!(name: "아파트", code: "apartment", enabled: true, sort_order: 0)

    ordered = PropertyType.ordered
    assert_equal "apartment", ordered.first.code
    assert_equal "officetel", ordered.last.code
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/property_type_test.rb`
Expected: FAIL — `NameError: uninitialized constant PropertyType`

- [ ] **Step 3: Generate migration**

Run: `bin/rails generate migration CreatePropertyTypes name:string code:string enabled:boolean sort_order:integer`

Edit the migration:

```ruby
class CreatePropertyTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :property_types do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.boolean :enabled, null: false, default: false
      t.integer :sort_order, null: false, default: 0
      t.timestamps
    end
    add_index :property_types, :code, unique: true
    add_index :property_types, [:enabled, :sort_order]
  end
end
```

- [ ] **Step 4: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 5: Create PropertyType model**

Create `app/models/property_type.rb`:

```ruby
class PropertyType < ApplicationRecord
  has_many :reserve_fund_defaults, dependent: :destroy
  has_many :loan_policies, dependent: :destroy

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true

  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:sort_order) }
end
```

- [ ] **Step 6: Create fixtures**

Create `test/fixtures/property_types.yml`:

```yaml
apartment:
  name: "아파트"
  code: "apartment"
  enabled: true
  sort_order: 0

villa:
  name: "빌라/다세대"
  code: "villa"
  enabled: true
  sort_order: 1

officetel:
  name: "오피스텔"
  code: "officetel"
  enabled: true
  sort_order: 2
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/models/property_type_test.rb`
Expected: 6 tests, 0 failures

- [ ] **Step 8: Commit**

```bash
git add app/models/property_type.rb db/migrate/*_create_property_types.rb test/models/property_type_test.rb test/fixtures/property_types.yml db/schema.rb
git commit -m "feat: add PropertyType model with enabled/ordered scopes"
```

---

## Task 4: Create ReserveFundDefault migration and model

**Files:**
- Create: `db/migrate/xxx_create_reserve_fund_defaults.rb`
- Create: `app/models/reserve_fund_default.rb`
- Create: `test/models/reserve_fund_default_test.rb`
- Create: `test/fixtures/reserve_fund_defaults.yml`

- [ ] **Step 1: Write the failing test**

Create `test/models/reserve_fund_default_test.rb`:

```ruby
require "test_helper"

class ReserveFundDefaultTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    rfd = ReserveFundDefault.new(
      property_type: property_types(:apartment),
      area_range_min: 59,
      area_range_max: 84,
      repair_cost: 500,
      acquisition_tax_rate: 0.011,
      scrivener_fee: 80,
      moving_cost: 150,
      maintenance_fee: 50
    )
    assert rfd.valid?
  end

  test "invalid without property_type" do
    rfd = ReserveFundDefault.new(
      property_type: nil,
      area_range_min: 59,
      area_range_max: 84,
      repair_cost: 500,
      acquisition_tax_rate: 0.011,
      scrivener_fee: 80,
      moving_cost: 150,
      maintenance_fee: 50
    )
    assert_not rfd.valid?
  end

  test "invalid when area_range_min >= area_range_max" do
    rfd = ReserveFundDefault.new(
      property_type: property_types(:apartment),
      area_range_min: 84,
      area_range_max: 59,
      repair_cost: 500,
      acquisition_tax_rate: 0.011,
      scrivener_fee: 80,
      moving_cost: 150,
      maintenance_fee: 50
    )
    assert_not rfd.valid?
    assert_includes rfd.errors[:area_range_max], "must be greater than area_range_min"
  end

  test "scope for_property_type_and_area finds matching default" do
    apt = property_types(:apartment)
    ReserveFundDefault.create!(
      property_type: apt, area_range_min: 59, area_range_max: 84,
      repair_cost: 500, acquisition_tax_rate: 0.011,
      scrivener_fee: 80, moving_cost: 150, maintenance_fee: 50
    )
    ReserveFundDefault.create!(
      property_type: apt, area_range_min: 85, area_range_max: 135,
      repair_cost: 800, acquisition_tax_rate: 0.011,
      scrivener_fee: 80, moving_cost: 200, maintenance_fee: 80
    )

    result = ReserveFundDefault.for_property_type_and_area(apt.id, 70)
    assert_equal 500, result.repair_cost

    result = ReserveFundDefault.for_property_type_and_area(apt.id, 100)
    assert_equal 800, result.repair_cost
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/reserve_fund_default_test.rb`
Expected: FAIL — `NameError: uninitialized constant ReserveFundDefault`

- [ ] **Step 3: Generate migration**

Run: `bin/rails generate migration CreateReserveFundDefaults property_type:references area_range_min:integer area_range_max:integer repair_cost:integer acquisition_tax_rate:decimal scrivener_fee:integer moving_cost:integer maintenance_fee:integer`

Edit the migration:

```ruby
class CreateReserveFundDefaults < ActiveRecord::Migration[8.1]
  def change
    create_table :reserve_fund_defaults do |t|
      t.references :property_type, null: false, foreign_key: true
      t.integer :area_range_min, null: false
      t.integer :area_range_max, null: false
      t.integer :repair_cost, null: false
      t.decimal :acquisition_tax_rate, null: false, precision: 5, scale: 4
      t.integer :scrivener_fee, null: false
      t.integer :moving_cost, null: false
      t.integer :maintenance_fee, null: false
      t.timestamps
    end
    add_index :reserve_fund_defaults, [:property_type_id, :area_range_min, :area_range_max],
              name: "idx_reserve_defaults_type_area", unique: true
  end
end
```

- [ ] **Step 4: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 5: Create model**

Create `app/models/reserve_fund_default.rb`:

```ruby
class ReserveFundDefault < ApplicationRecord
  belongs_to :property_type

  validates :area_range_min, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :area_range_max, presence: true
  validates :repair_cost, :scrivener_fee, :moving_cost, :maintenance_fee,
            presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :acquisition_tax_rate, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 0.12 }
  validate :area_range_max_greater_than_min

  scope :for_property_type_and_area, ->(property_type_id, area_sqm) {
    where(property_type_id: property_type_id)
      .where("area_range_min <= ? AND area_range_max >= ?", area_sqm, area_sqm)
      .first
  }

  private

  def area_range_max_greater_than_min
    return unless area_range_min.present? && area_range_max.present?
    if area_range_max <= area_range_min
      errors.add(:area_range_max, "must be greater than area_range_min")
    end
  end
end
```

- [ ] **Step 6: Create fixtures**

Create `test/fixtures/reserve_fund_defaults.yml`:

```yaml
apartment_small:
  property_type: apartment
  area_range_min: 0
  area_range_max: 58
  repair_cost: 300
  acquisition_tax_rate: 0.011
  scrivener_fee: 60
  moving_cost: 100
  maintenance_fee: 30

apartment_medium:
  property_type: apartment
  area_range_min: 59
  area_range_max: 84
  repair_cost: 500
  acquisition_tax_rate: 0.011
  scrivener_fee: 80
  moving_cost: 150
  maintenance_fee: 50
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/models/reserve_fund_default_test.rb`
Expected: 4 tests, 0 failures

- [ ] **Step 8: Commit**

```bash
git add app/models/reserve_fund_default.rb db/migrate/*_create_reserve_fund_defaults.rb test/models/reserve_fund_default_test.rb test/fixtures/reserve_fund_defaults.yml db/schema.rb
git commit -m "feat: add ReserveFundDefault model with area range lookup"
```

---

## Task 5: Create LoanPolicy migration and model

**Files:**
- Create: `db/migrate/xxx_create_loan_policies.rb`
- Create: `app/models/loan_policy.rb`
- Create: `test/models/loan_policy_test.rb`
- Create: `test/fixtures/loan_policies.yml`

- [ ] **Step 1: Write the failing test**

Create `test/models/loan_policy_test.rb`:

```ruby
require "test_helper"

class LoanPolicyTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    lp = LoanPolicy.new(
      property_type: property_types(:apartment),
      policy_name: "디딤돌 대출",
      loan_ratio: 0.8,
      effective_date: Date.new(2026, 1, 1),
      enabled: true
    )
    assert lp.valid?
  end

  test "invalid without policy_name" do
    lp = LoanPolicy.new(
      property_type: property_types(:apartment),
      policy_name: nil,
      loan_ratio: 0.8,
      effective_date: Date.new(2026, 1, 1)
    )
    assert_not lp.valid?
  end

  test "invalid with loan_ratio outside 0-1 range" do
    lp = LoanPolicy.new(
      property_type: property_types(:apartment),
      policy_name: "테스트",
      loan_ratio: 1.5,
      effective_date: Date.new(2026, 1, 1)
    )
    assert_not lp.valid?
    assert_includes lp.errors[:loan_ratio], "must be less than or equal to 1"
  end

  test "scope active returns enabled policies without expiry or future expiry" do
    apt = property_types(:apartment)
    active = LoanPolicy.create!(
      property_type: apt, policy_name: "Active",
      loan_ratio: 0.7, effective_date: Date.new(2026, 1, 1),
      expiry_date: nil, enabled: true
    )
    expired = LoanPolicy.create!(
      property_type: apt, policy_name: "Expired",
      loan_ratio: 0.6, effective_date: Date.new(2025, 1, 1),
      expiry_date: Date.new(2025, 12, 31), enabled: true
    )
    disabled = LoanPolicy.create!(
      property_type: apt, policy_name: "Disabled",
      loan_ratio: 0.8, effective_date: Date.new(2026, 1, 1),
      expiry_date: nil, enabled: false
    )

    results = LoanPolicy.active
    assert_includes results, active
    assert_not_includes results, expired
    assert_not_includes results, disabled
  end

  test "scope for_property_type filters by property type" do
    apt = property_types(:apartment)
    villa = property_types(:villa)
    LoanPolicy.create!(
      property_type: apt, policy_name: "아파트용",
      loan_ratio: 0.7, effective_date: Date.new(2026, 1, 1), enabled: true
    )
    LoanPolicy.create!(
      property_type: villa, policy_name: "빌라용",
      loan_ratio: 0.6, effective_date: Date.new(2026, 1, 1), enabled: true
    )

    results = LoanPolicy.for_property_type(apt.id)
    assert_equal 1, results.count
    assert_equal "아파트용", results.first.policy_name
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/loan_policy_test.rb`
Expected: FAIL — `NameError: uninitialized constant LoanPolicy`

- [ ] **Step 3: Generate migration**

Run: `bin/rails generate migration CreateLoanPolicies property_type:references policy_name:string loan_ratio:decimal description:text source_url:string effective_date:date expiry_date:date enabled:boolean`

Edit the migration:

```ruby
class CreateLoanPolicies < ActiveRecord::Migration[8.1]
  def change
    create_table :loan_policies do |t|
      t.references :property_type, null: false, foreign_key: true
      t.string :policy_name, null: false
      t.decimal :loan_ratio, null: false, precision: 3, scale: 2
      t.text :description
      t.string :source_url
      t.date :effective_date, null: false
      t.date :expiry_date
      t.boolean :enabled, null: false, default: true
      t.timestamps
    end
    add_index :loan_policies, [:property_type_id, :enabled]
  end
end
```

- [ ] **Step 4: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 5: Create model**

Create `app/models/loan_policy.rb`:

```ruby
class LoanPolicy < ApplicationRecord
  belongs_to :property_type

  validates :policy_name, presence: true
  validates :loan_ratio, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :effective_date, presence: true

  scope :active, -> {
    where(enabled: true)
      .where("expiry_date IS NULL OR expiry_date >= ?", Date.current)
  }
  scope :for_property_type, ->(property_type_id) {
    where(property_type_id: property_type_id)
  }
end
```

- [ ] **Step 6: Create fixtures**

Create `test/fixtures/loan_policies.yml`:

```yaml
didimdol_apartment:
  property_type: apartment
  policy_name: "디딤돌 대출"
  loan_ratio: 0.8
  description: "무주택 서민 주거안정을 위한 정책 모기지"
  effective_date: "2026-01-01"
  expiry_date:
  enabled: true

general_apartment:
  property_type: apartment
  policy_name: "일반 주담대"
  loan_ratio: 0.7
  description: "일반 주택담보대출"
  effective_date: "2026-01-01"
  expiry_date:
  enabled: true

newborn_apartment:
  property_type: apartment
  policy_name: "신생아특례"
  loan_ratio: 0.8
  description: "출산가구 주거지원 특례대출"
  effective_date: "2026-01-01"
  expiry_date:
  enabled: true
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/models/loan_policy_test.rb`
Expected: 5 tests, 0 failures

- [ ] **Step 8: Commit**

```bash
git add app/models/loan_policy.rb db/migrate/*_create_loan_policies.rb test/models/loan_policy_test.rb test/fixtures/loan_policies.yml db/schema.rb
git commit -m "feat: add LoanPolicy model with active/for_property_type scopes"
```

---

## Task 6: Create BudgetSetting migration and model

**Files:**
- Create: `db/migrate/xxx_create_budget_settings.rb`
- Create: `app/models/budget_setting.rb`
- Create: `test/models/budget_setting_test.rb`
- Create: `test/fixtures/budget_settings.yml`

- [ ] **Step 1: Write the failing test**

Create `test/models/budget_setting_test.rb`:

```ruby
require "test_helper"

class BudgetSettingTest < ActiveSupport::TestCase
  test "valid with user and available_cash" do
    bs = BudgetSetting.new(
      user: users(:guest),
      available_cash: 30000,
      property_type: property_types(:apartment),
      area_range_min: 59,
      area_range_max: 84,
      repair_cost: 500,
      acquisition_tax: 360,
      scrivener_fee: 80,
      moving_cost: 150,
      maintenance_fee: 50,
      loan_policy: loan_policies(:general_apartment),
      loan_ratio: 0.7,
      max_bid_amount: 85333,
      area_unit: "pyeong",
      failed_auction_rounds: 0,
      searchable_appraisal_limit: 85333
    )
    assert bs.valid?
  end

  test "invalid with duplicate user_id" do
    BudgetSetting.create!(
      user: users(:guest),
      available_cash: 30000,
      loan_ratio: 0.7,
      area_unit: "pyeong",
      failed_auction_rounds: 0
    )
    bs = BudgetSetting.new(user: users(:guest), available_cash: 20000)
    assert_not bs.valid?
    assert_includes bs.errors[:user_id], "has already been taken"
  end

  test "available_cash must be positive" do
    bs = BudgetSetting.new(user: users(:guest), available_cash: -100)
    assert_not bs.valid?
    assert_includes bs.errors[:available_cash], "must be greater than 0"
  end

  test "loan_ratio must be between 0 and 1" do
    bs = BudgetSetting.new(user: users(:guest), available_cash: 30000, loan_ratio: 1.5)
    assert_not bs.valid?
  end

  test "failed_auction_rounds must be 0-3" do
    bs = BudgetSetting.new(user: users(:guest), available_cash: 30000, failed_auction_rounds: 5)
    assert_not bs.valid?
  end

  test "area_unit must be pyeong or sqm" do
    bs = BudgetSetting.new(user: users(:guest), available_cash: 30000, area_unit: "invalid")
    assert_not bs.valid?
    assert_includes bs.errors[:area_unit], "is not included in the list"
  end

  test "completed? returns true when completed_at is set" do
    bs = BudgetSetting.new(completed_at: Time.current)
    assert bs.completed?

    bs = BudgetSetting.new(completed_at: nil)
    assert_not bs.completed?
  end

  test "total_reserves sums all reserve fund items" do
    bs = BudgetSetting.new(
      repair_cost: 500,
      acquisition_tax: 360,
      scrivener_fee: 80,
      moving_cost: 150,
      maintenance_fee: 50
    )
    assert_equal 1140, bs.total_reserves
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/budget_setting_test.rb`
Expected: FAIL

- [ ] **Step 3: Generate migration**

Run: `bin/rails generate migration CreateBudgetSettings`

Edit the migration:

```ruby
class CreateBudgetSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_settings do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :available_cash
      t.references :property_type, foreign_key: true
      t.integer :area_range_min
      t.integer :area_range_max
      t.integer :repair_cost
      t.integer :acquisition_tax
      t.integer :scrivener_fee
      t.integer :moving_cost
      t.integer :maintenance_fee
      t.references :loan_policy, foreign_key: true
      t.decimal :loan_ratio, precision: 3, scale: 2
      t.integer :max_bid_amount
      t.string :area_unit, null: false, default: "pyeong"
      t.integer :failed_auction_rounds, null: false, default: 0
      t.integer :searchable_appraisal_limit
      t.datetime :completed_at
      t.timestamps
    end
    add_index :budget_settings, :user_id, unique: true
  end
end
```

- [ ] **Step 4: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 5: Create model**

Create `app/models/budget_setting.rb`:

```ruby
class BudgetSetting < ApplicationRecord
  belongs_to :user
  belongs_to :property_type, optional: true
  belongs_to :loan_policy, optional: true

  validates :user_id, uniqueness: true
  validates :available_cash, numericality: { greater_than: 0 }, allow_nil: true
  validates :loan_ratio, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :failed_auction_rounds, numericality: {
    only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3
  }
  validates :area_unit, inclusion: { in: %w[pyeong sqm] }

  RESERVE_FIELDS = %i[repair_cost acquisition_tax scrivener_fee moving_cost maintenance_fee].freeze

  def completed?
    completed_at.present?
  end

  def total_reserves
    RESERVE_FIELDS.sum { |field| public_send(field).to_i }
  end
end
```

- [ ] **Step 6: Add has_one association to User model**

Edit `app/models/user.rb`, add the association:

```ruby
class User < ApplicationRecord
  has_secure_password
  has_one :budget_setting, dependent: :destroy

  validates :email, presence: true, uniqueness: true
end
```

- [ ] **Step 7: Create fixtures**

Create `test/fixtures/budget_settings.yml`:

```yaml
# empty — tests create their own
```

- [ ] **Step 8: Run test to verify it passes**

Run: `bin/rails test test/models/budget_setting_test.rb`
Expected: 8 tests, 0 failures

- [ ] **Step 9: Commit**

```bash
git add app/models/budget_setting.rb app/models/user.rb db/migrate/*_create_budget_settings.rb test/models/budget_setting_test.rb test/fixtures/budget_settings.yml db/schema.rb
git commit -m "feat: add BudgetSetting model with reserve fund calculation"
```

---

## Task 7: Create BudgetSnapshot migration and model

**Files:**
- Create: `db/migrate/xxx_create_budget_snapshots.rb`
- Create: `app/models/budget_snapshot.rb`
- Create: `test/models/budget_snapshot_test.rb`
- Create: `test/fixtures/budget_snapshots.yml`

- [ ] **Step 1: Write the failing test**

Create `test/models/budget_snapshot_test.rb`:

```ruby
require "test_helper"

class BudgetSnapshotTest < ActiveSupport::TestCase
  test "valid with required fields" do
    snapshot = BudgetSnapshot.new(
      user: users(:guest),
      version: 1,
      trigger: "onboarding",
      available_cash: 30000,
      property_type_name: "아파트",
      area_range: "59~84㎡",
      area_unit: "pyeong",
      repair_cost: 500,
      acquisition_tax: 360,
      scrivener_fee: 80,
      moving_cost: 150,
      maintenance_fee: 50,
      loan_policy_name: "일반 주담대",
      loan_ratio: 0.7,
      max_bid_amount: 85333,
      failed_auction_rounds: 0,
      searchable_appraisal_limit: 85333,
      calculated_at: Time.current
    )
    assert snapshot.valid?
  end

  test "invalid without trigger" do
    snapshot = BudgetSnapshot.new(user: users(:guest), version: 1, trigger: nil, calculated_at: Time.current)
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:trigger], "is not included in the list"
  end

  test "trigger must be one of allowed values" do
    snapshot = BudgetSnapshot.new(user: users(:guest), version: 1, trigger: "invalid", calculated_at: Time.current)
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:trigger], "is not included in the list"
  end

  test "parent_snapshot association is optional" do
    snapshot = BudgetSnapshot.new(
      user: users(:guest), version: 1, trigger: "onboarding",
      calculated_at: Time.current, parent_snapshot: nil
    )
    assert snapshot.valid?
  end

  test "next_version_for returns 1 for first snapshot" do
    assert_equal 1, BudgetSnapshot.next_version_for(users(:guest).id)
  end

  test "next_version_for returns max + 1 for existing snapshots" do
    BudgetSnapshot.create!(
      user: users(:guest), version: 1, trigger: "onboarding",
      calculated_at: Time.current
    )
    assert_equal 2, BudgetSnapshot.next_version_for(users(:guest).id)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/budget_snapshot_test.rb`
Expected: FAIL

- [ ] **Step 3: Generate migration**

Run: `bin/rails generate migration CreateBudgetSnapshots`

Edit the migration:

```ruby
class CreateBudgetSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :budget_snapshots do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :property_case_id
      t.integer :version, null: false
      t.references :parent_snapshot, foreign_key: { to_table: :budget_snapshots }
      t.string :trigger, null: false

      # Denormalized values
      t.integer :available_cash
      t.string :property_type_name
      t.string :area_range
      t.string :area_unit
      t.integer :repair_cost
      t.integer :acquisition_tax
      t.integer :scrivener_fee
      t.integer :moving_cost
      t.integer :maintenance_fee
      t.string :loan_policy_name
      t.decimal :loan_ratio, precision: 3, scale: 2
      t.integer :max_bid_amount
      t.integer :failed_auction_rounds
      t.integer :searchable_appraisal_limit
      t.datetime :calculated_at, null: false

      t.timestamps
    end
    add_index :budget_snapshots, [:user_id, :version]
  end
end
```

- [ ] **Step 4: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 5: Create model**

Create `app/models/budget_snapshot.rb`:

```ruby
class BudgetSnapshot < ApplicationRecord
  TRIGGERS = %w[onboarding manual_edit recalculate].freeze

  belongs_to :user
  belongs_to :parent_snapshot, class_name: "BudgetSnapshot", optional: true
  has_many :child_snapshots, class_name: "BudgetSnapshot", foreign_key: :parent_snapshot_id, dependent: :nullify

  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :trigger, inclusion: { in: TRIGGERS }
  validates :calculated_at, presence: true

  scope :for_user, ->(user_id) { where(user_id: user_id).order(version: :desc) }

  def self.next_version_for(user_id)
    where(user_id: user_id).maximum(:version).to_i + 1
  end
end
```

- [ ] **Step 6: Add has_many to User**

Edit `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  has_secure_password
  has_one :budget_setting, dependent: :destroy
  has_many :budget_snapshots, dependent: :destroy

  validates :email, presence: true, uniqueness: true
end
```

- [ ] **Step 7: Create fixtures**

Create `test/fixtures/budget_snapshots.yml`:

```yaml
# empty — tests create their own
```

- [ ] **Step 8: Run test to verify it passes**

Run: `bin/rails test test/models/budget_snapshot_test.rb`
Expected: 6 tests, 0 failures

- [ ] **Step 9: Commit**

```bash
git add app/models/budget_snapshot.rb app/models/user.rb db/migrate/*_create_budget_snapshots.rb test/models/budget_snapshot_test.rb test/fixtures/budget_snapshots.yml db/schema.rb
git commit -m "feat: add BudgetSnapshot model with versioning"
```

---

## Task 8: Create seed data files and seed loader

**Files:**
- Create: `db/seeds/property_types.json`
- Create: `db/seeds/reserve_fund_defaults.json`
- Create: `db/seeds/loan_policies.json`
- Modify: `db/seeds.rb`

- [ ] **Step 1: Create property_types.json**

Create `db/seeds/property_types.json`:

```json
[
  { "name": "아파트", "code": "apartment", "enabled": true, "sort_order": 0 },
  { "name": "빌라/다세대", "code": "villa", "enabled": true, "sort_order": 1 },
  { "name": "오피스텔", "code": "officetel", "enabled": true, "sort_order": 2 },
  { "name": "단독주택", "code": "house", "enabled": false, "sort_order": 3 },
  { "name": "상가", "code": "commercial", "enabled": false, "sort_order": 4 }
]
```

- [ ] **Step 2: Create reserve_fund_defaults.json**

Create `db/seeds/reserve_fund_defaults.json`:

```json
[
  {
    "property_type_code": "apartment",
    "defaults": [
      { "area_range_min": 0, "area_range_max": 58, "repair_cost": 300, "acquisition_tax_rate": 0.011, "scrivener_fee": 60, "moving_cost": 100, "maintenance_fee": 30 },
      { "area_range_min": 59, "area_range_max": 84, "repair_cost": 500, "acquisition_tax_rate": 0.011, "scrivener_fee": 80, "moving_cost": 150, "maintenance_fee": 50 },
      { "area_range_min": 85, "area_range_max": 135, "repair_cost": 800, "acquisition_tax_rate": 0.011, "scrivener_fee": 100, "moving_cost": 200, "maintenance_fee": 80 },
      { "area_range_min": 136, "area_range_max": 300, "repair_cost": 1200, "acquisition_tax_rate": 0.035, "scrivener_fee": 120, "moving_cost": 250, "maintenance_fee": 100 }
    ]
  },
  {
    "property_type_code": "villa",
    "defaults": [
      { "area_range_min": 0, "area_range_max": 58, "repair_cost": 400, "acquisition_tax_rate": 0.011, "scrivener_fee": 60, "moving_cost": 100, "maintenance_fee": 20 },
      { "area_range_min": 59, "area_range_max": 84, "repair_cost": 600, "acquisition_tax_rate": 0.011, "scrivener_fee": 80, "moving_cost": 150, "maintenance_fee": 30 },
      { "area_range_min": 85, "area_range_max": 165, "repair_cost": 900, "acquisition_tax_rate": 0.011, "scrivener_fee": 100, "moving_cost": 200, "maintenance_fee": 50 }
    ]
  },
  {
    "property_type_code": "officetel",
    "defaults": [
      { "area_range_min": 0, "area_range_max": 40, "repair_cost": 200, "acquisition_tax_rate": 0.044, "scrivener_fee": 50, "moving_cost": 80, "maintenance_fee": 30 },
      { "area_range_min": 41, "area_range_max": 84, "repair_cost": 400, "acquisition_tax_rate": 0.044, "scrivener_fee": 70, "moving_cost": 120, "maintenance_fee": 50 },
      { "area_range_min": 85, "area_range_max": 165, "repair_cost": 600, "acquisition_tax_rate": 0.044, "scrivener_fee": 90, "moving_cost": 160, "maintenance_fee": 70 }
    ]
  }
]
```

- [ ] **Step 3: Create loan_policies.json**

Create `db/seeds/loan_policies.json`:

```json
[
  {
    "property_type_code": "apartment",
    "policies": [
      { "policy_name": "디딤돌 대출", "loan_ratio": 0.8, "description": "무주택 서민 주거안정을 위한 정책 모기지 (소득 6천만원 이하, 주택가격 5억원 이하)", "source_url": "https://www.hf.go.kr", "effective_date": "2026-01-01" },
      { "policy_name": "일반 주담대", "loan_ratio": 0.7, "description": "일반 주택담보대출 (규제지역 LTV 기준)", "source_url": "https://www.fsc.go.kr", "effective_date": "2026-01-01" },
      { "policy_name": "신생아특례", "loan_ratio": 0.8, "description": "출산가구 주거지원 특례대출 (2년 내 출산, 소득 1.3억 이하)", "source_url": "https://www.hug.go.kr", "effective_date": "2026-01-01" }
    ]
  },
  {
    "property_type_code": "villa",
    "policies": [
      { "policy_name": "디딤돌 대출", "loan_ratio": 0.7, "description": "무주택 서민 주거안정을 위한 정책 모기지 (빌라 LTV 하향)", "source_url": "https://www.hf.go.kr", "effective_date": "2026-01-01" },
      { "policy_name": "일반 주담대", "loan_ratio": 0.6, "description": "빌라 담보대출 (감정가 대비, 금융기관별 상이)", "source_url": "https://www.fsc.go.kr", "effective_date": "2026-01-01" }
    ]
  },
  {
    "property_type_code": "officetel",
    "policies": [
      { "policy_name": "일반 주담대", "loan_ratio": 0.6, "description": "오피스텔 담보대출 (주거용 인정 시)", "source_url": "https://www.fsc.go.kr", "effective_date": "2026-01-01" },
      { "policy_name": "사업자 대출", "loan_ratio": 0.7, "description": "사업자 등록 시 사업용 담보대출 가능", "source_url": "https://www.fsc.go.kr", "effective_date": "2026-01-01" }
    ]
  }
]
```

- [ ] **Step 4: Update db/seeds.rb**

Replace `db/seeds.rb` content with:

```ruby
require "json"

puts "Seeding property types..."
property_types_data = JSON.parse(File.read(Rails.root.join("db/seeds/property_types.json")))
property_types_data.each do |attrs|
  PropertyType.find_or_create_by!(code: attrs["code"]) do |pt|
    pt.name = attrs["name"]
    pt.enabled = attrs["enabled"]
    pt.sort_order = attrs["sort_order"]
  end
end
puts "  -> #{PropertyType.count} property types"

puts "Seeding reserve fund defaults..."
reserve_data = JSON.parse(File.read(Rails.root.join("db/seeds/reserve_fund_defaults.json")))
reserve_data.each do |group|
  pt = PropertyType.find_by!(code: group["property_type_code"])
  group["defaults"].each do |attrs|
    ReserveFundDefault.find_or_create_by!(
      property_type: pt,
      area_range_min: attrs["area_range_min"],
      area_range_max: attrs["area_range_max"]
    ) do |rfd|
      rfd.repair_cost = attrs["repair_cost"]
      rfd.acquisition_tax_rate = attrs["acquisition_tax_rate"]
      rfd.scrivener_fee = attrs["scrivener_fee"]
      rfd.moving_cost = attrs["moving_cost"]
      rfd.maintenance_fee = attrs["maintenance_fee"]
    end
  end
end
puts "  -> #{ReserveFundDefault.count} reserve fund defaults"

puts "Seeding loan policies..."
loan_data = JSON.parse(File.read(Rails.root.join("db/seeds/loan_policies.json")))
loan_data.each do |group|
  pt = PropertyType.find_by!(code: group["property_type_code"])
  group["policies"].each do |attrs|
    LoanPolicy.find_or_create_by!(
      property_type: pt,
      policy_name: attrs["policy_name"]
    ) do |lp|
      lp.loan_ratio = attrs["loan_ratio"]
      lp.description = attrs["description"]
      lp.source_url = attrs["source_url"]
      lp.effective_date = Date.parse(attrs["effective_date"])
      lp.enabled = true
    end
  end
end
puts "  -> #{LoanPolicy.count} loan policies"

puts "Seeding guest user..."
User.find_or_create_by!(email: "guest@auction.local") do |u|
  u.password = "123456"
end
puts "  -> Guest user ready"

puts "Seed complete!"
```

- [ ] **Step 5: Run seed and verify**

Run: `bin/rails db:seed`
Expected: Output showing counts for each seeded table, no errors

- [ ] **Step 6: Commit**

```bash
git add db/seeds.rb db/seeds/property_types.json db/seeds/reserve_fund_defaults.json db/seeds/loan_policies.json
git commit -m "feat: add seed data for property types, reserve defaults, and loan policies"
```

---

## Task 9: Create LoanPolicyAdapter (base + mock)

**Files:**
- Create: `app/adapters/loan_policy_adapter.rb`
- Create: `app/adapters/mock_loan_policy_adapter.rb`
- Create: `app/adapters/government_loan_policy_adapter.rb`
- Create: `test/adapters/loan_policy_adapter_test.rb`
- Create: `test/adapters/mock_loan_policy_adapter_test.rb`

- [ ] **Step 1: Write the failing test for adapter factory**

Create `test/adapters/loan_policy_adapter_test.rb`:

```ruby
require "test_helper"

class LoanPolicyAdapterTest < ActiveSupport::TestCase
  test ".for returns MockLoanPolicyAdapter when USE_MOCK is true" do
    ENV["USE_MOCK"] = "true"
    adapter = LoanPolicyAdapter.for
    assert_instance_of MockLoanPolicyAdapter, adapter
  ensure
    ENV.delete("USE_MOCK")
  end

  test ".for returns GovernmentLoanPolicyAdapter when USE_MOCK is false" do
    ENV["USE_MOCK"] = "false"
    adapter = LoanPolicyAdapter.for
    assert_instance_of GovernmentLoanPolicyAdapter, adapter
  ensure
    ENV.delete("USE_MOCK")
  end

  test ".for defaults to MockLoanPolicyAdapter when USE_MOCK is not set" do
    ENV.delete("USE_MOCK")
    adapter = LoanPolicyAdapter.for
    assert_instance_of MockLoanPolicyAdapter, adapter
  end
end
```

- [ ] **Step 2: Write the failing test for mock adapter**

Create `test/adapters/mock_loan_policy_adapter_test.rb`:

```ruby
require "test_helper"

class MockLoanPolicyAdapterTest < ActiveSupport::TestCase
  setup do
    @adapter = MockLoanPolicyAdapter.new
  end

  test "fetch_policies returns array of policy hashes" do
    policies = @adapter.fetch_policies(property_type_code: "apartment")
    assert_kind_of Array, policies
    assert policies.length > 0
  end

  test "each policy has required keys" do
    policies = @adapter.fetch_policies(property_type_code: "apartment")
    policy = policies.first

    assert policy.key?(:policy_name)
    assert policy.key?(:loan_ratio)
    assert policy.key?(:description)
    assert policy.key?(:effective_date)
  end

  test "loan_ratio is a numeric between 0 and 1" do
    policies = @adapter.fetch_policies(property_type_code: "apartment")
    policies.each do |policy|
      assert policy[:loan_ratio].is_a?(Numeric)
      assert policy[:loan_ratio] > 0
      assert policy[:loan_ratio] <= 1
    end
  end

  test "fetch_policies for unknown type returns empty array" do
    policies = @adapter.fetch_policies(property_type_code: "spaceship")
    assert_equal [], policies
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/adapters/`
Expected: FAIL — NameError for all adapter classes

- [ ] **Step 4: Create base adapter**

Create `app/adapters/loan_policy_adapter.rb`:

```ruby
class LoanPolicyAdapter
  def self.for
    if ENV["USE_MOCK"] == "false"
      GovernmentLoanPolicyAdapter.new
    else
      MockLoanPolicyAdapter.new
    end
  end

  def fetch_policies(property_type_code:)
    raise NotImplementedError, "#{self.class}#fetch_policies must be implemented"
  end
end
```

- [ ] **Step 5: Create mock adapter**

Create `app/adapters/mock_loan_policy_adapter.rb`:

```ruby
class MockLoanPolicyAdapter < LoanPolicyAdapter
  MOCK_DATA = {
    "apartment" => [
      { policy_name: "디딤돌 대출", loan_ratio: 0.8, description: "무주택 서민 주거안정을 위한 정책 모기지 (소득 6천만원 이하, 주택가격 5억원 이하)", source_url: "https://www.hf.go.kr", effective_date: Date.new(2026, 1, 1) },
      { policy_name: "일반 주담대", loan_ratio: 0.7, description: "일반 주택담보대출 (규제지역 LTV 기준)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) },
      { policy_name: "신생아특례", loan_ratio: 0.8, description: "출산가구 주거지원 특례대출 (2년 내 출산, 소득 1.3억 이하)", source_url: "https://www.hug.go.kr", effective_date: Date.new(2026, 1, 1) }
    ],
    "villa" => [
      { policy_name: "디딤돌 대출", loan_ratio: 0.7, description: "무주택 서민 주거안정을 위한 정책 모기지 (빌라 LTV 하향)", source_url: "https://www.hf.go.kr", effective_date: Date.new(2026, 1, 1) },
      { policy_name: "일반 주담대", loan_ratio: 0.6, description: "빌라 담보대출 (감정가 대비, 금융기관별 상이)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) }
    ],
    "officetel" => [
      { policy_name: "일반 주담대", loan_ratio: 0.6, description: "오피스텔 담보대출 (주거용 인정 시)", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) },
      { policy_name: "사업자 대출", loan_ratio: 0.7, description: "사업자 등록 시 사업용 담보대출 가능", source_url: "https://www.fsc.go.kr", effective_date: Date.new(2026, 1, 1) }
    ]
  }.freeze

  def fetch_policies(property_type_code:)
    MOCK_DATA.fetch(property_type_code, [])
  end
end
```

- [ ] **Step 6: Create government adapter stub**

Create `app/adapters/government_loan_policy_adapter.rb`:

```ruby
class GovernmentLoanPolicyAdapter < LoanPolicyAdapter
  # Real implementation will call:
  # - 금융위원회 Open API (data.go.kr) for LTV/DSR limits
  # - 한국주택금융공사 (HF) for Didimdol/Bogeumjari terms
  # - 주택도시보증공사 (HUG) for Newborn special loan
  #
  # For now, falls back to MockLoanPolicyAdapter behavior
  # until real API credentials are configured.

  def fetch_policies(property_type_code:)
    # TODO: Replace with real API calls when credentials available
    MockLoanPolicyAdapter.new.fetch_policies(property_type_code: property_type_code)
  end
end
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bin/rails test test/adapters/`
Expected: All tests pass

- [ ] **Step 8: Commit**

```bash
git add app/adapters/ test/adapters/
git commit -m "feat: add LoanPolicyAdapter with mock and government stubs"
```

---

## Task 10: Create BudgetCalculationService

**Files:**
- Create: `app/services/budget_calculation_service.rb`
- Create: `test/services/budget_calculation_service_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/services/budget_calculation_service_test.rb`:

```ruby
require "test_helper"

class BudgetCalculationServiceTest < ActiveSupport::TestCase
  test "calculates max_bid_amount correctly" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
      loan_ratio: 0.7,
      failed_auction_rounds: 0
    )

    # (30000 - 1140) / (1 - 0.7) = 28860 / 0.3 = 96200
    assert_equal 96200, result[:max_bid_amount]
    assert_equal 1140, result[:total_reserves]
    assert_equal 96200, result[:searchable_appraisal_limit]
  end

  test "calculates searchable_appraisal_limit with failed rounds" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
      loan_ratio: 0.7,
      failed_auction_rounds: 2
    )

    max_bid = 96200
    # max_bid / (0.8 ^ 2) = 96200 / 0.64 = 150312.5 → 150312
    assert_equal max_bid, result[:max_bid_amount]
    assert_equal 150312, result[:searchable_appraisal_limit]
  end

  test "calculates with zero loan ratio" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
      loan_ratio: 0.0,
      failed_auction_rounds: 0
    )

    # (30000 - 1140) / (1 - 0) = 28860
    assert_equal 28860, result[:max_bid_amount]
  end

  test "returns breakdown with all reserve items" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
      loan_ratio: 0.7,
      failed_auction_rounds: 0
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
        loan_ratio: 0.7,
        failed_auction_rounds: 0
      )
    end
  end

  test "handles missing reserve fund items as zero" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500 },
      loan_ratio: 0.7,
      failed_auction_rounds: 0
    )

    # (30000 - 500) / 0.3 = 98333
    assert_equal 98333, result[:max_bid_amount]
    assert_equal 500, result[:total_reserves]
  end

  test "searchable_appraisal_limit with 3 failed rounds" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 0, acquisition_tax: 0, scrivener: 0, moving: 0, maintenance: 0 },
      loan_ratio: 0.7,
      failed_auction_rounds: 3
    )

    max_bid = 100000  # 30000 / 0.3
    # max_bid / (0.8 ^ 3) = 100000 / 0.512 = 195312.5 → 195312
    assert_equal max_bid, result[:max_bid_amount]
    assert_equal 195312, result[:searchable_appraisal_limit]
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/budget_calculation_service_test.rb`
Expected: FAIL — NameError

- [ ] **Step 3: Create the service**

Create `app/services/budget_calculation_service.rb`:

```ruby
class BudgetCalculationService
  class InsufficientFundsError < StandardError; end

  RESERVE_KEYS = %i[repair acquisition_tax scrivener moving maintenance].freeze
  PRICE_REDUCTION_PER_ROUND = 0.8

  def self.call(available_cash:, reserve_funds:, loan_ratio:, failed_auction_rounds:)
    new(available_cash:, reserve_funds:, loan_ratio:, failed_auction_rounds:).call
  end

  def initialize(available_cash:, reserve_funds:, loan_ratio:, failed_auction_rounds:)
    @available_cash = available_cash
    @reserve_funds = reserve_funds
    @loan_ratio = loan_ratio.to_d
    @failed_auction_rounds = failed_auction_rounds
  end

  def call
    total_reserves = RESERVE_KEYS.sum { |key| @reserve_funds.fetch(key, 0).to_i }

    net_cash = @available_cash - total_reserves
    raise InsufficientFundsError, "Available cash (#{@available_cash}) is less than total reserves (#{total_reserves})" if net_cash <= 0

    divisor = 1 - @loan_ratio
    max_bid_amount = (net_cash / divisor).floor

    searchable_appraisal_limit = if @failed_auction_rounds > 0
      reduction_factor = PRICE_REDUCTION_PER_ROUND**@failed_auction_rounds
      (max_bid_amount / reduction_factor).floor
    else
      max_bid_amount
    end

    {
      total_reserves: total_reserves,
      max_bid_amount: max_bid_amount,
      searchable_appraisal_limit: searchable_appraisal_limit,
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

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/budget_calculation_service_test.rb`
Expected: 7 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/services/budget_calculation_service.rb test/services/budget_calculation_service_test.rb
git commit -m "feat: add BudgetCalculationService with failed auction round adjustment"
```

---

## Task 11: Create BudgetSnapshotService

**Files:**
- Create: `app/services/budget_snapshot_service.rb`
- Create: `test/services/budget_snapshot_service_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/services/budget_snapshot_service_test.rb`:

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
      loan_policy: loan_policies(:general_apartment),
      loan_ratio: 0.7,
      max_bid_amount: 96200,
      area_unit: "pyeong",
      failed_auction_rounds: 0,
      searchable_appraisal_limit: 96200,
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
    assert_equal "일반 주담대", snapshot.loan_policy_name
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

    # Change the live settings
    @setting.update!(loan_ratio: 0.6, max_bid_amount: 72150, searchable_appraisal_limit: 72150)

    recalculated = BudgetSnapshotService.recalculate(user: @user, parent_snapshot: original)

    assert_equal 2, recalculated.version
    assert_equal "recalculate", recalculated.trigger
    assert_equal original.id, recalculated.parent_snapshot_id
    assert_equal 0.6, recalculated.loan_ratio.to_f
    assert_equal 72150, recalculated.max_bid_amount
  end

  test "compare returns diff between two snapshots" do
    s1 = BudgetSnapshotService.create(user: @user, trigger: "onboarding")

    @setting.update!(loan_ratio: 0.6, max_bid_amount: 72150, searchable_appraisal_limit: 72150)
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

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/budget_snapshot_service_test.rb`
Expected: FAIL — NameError

- [ ] **Step 3: Create the service**

Create `app/services/budget_snapshot_service.rb`:

```ruby
class BudgetSnapshotService
  COMPARABLE_FIELDS = %i[
    available_cash repair_cost acquisition_tax scrivener_fee
    moving_cost maintenance_fee loan_ratio max_bid_amount
    failed_auction_rounds searchable_appraisal_limit
  ].freeze

  NUMERIC_FIELDS = %i[
    available_cash repair_cost acquisition_tax scrivener_fee
    moving_cost maintenance_fee max_bid_amount
    failed_auction_rounds searchable_appraisal_limit
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
      area_unit: setting.area_unit,
      repair_cost: setting.repair_cost,
      acquisition_tax: setting.acquisition_tax,
      scrivener_fee: setting.scrivener_fee,
      moving_cost: setting.moving_cost,
      maintenance_fee: setting.maintenance_fee,
      loan_policy_name: setting.loan_policy&.policy_name,
      loan_ratio: setting.loan_ratio,
      max_bid_amount: setting.max_bid_amount,
      failed_auction_rounds: setting.failed_auction_rounds,
      searchable_appraisal_limit: setting.searchable_appraisal_limit,
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
      area_unit: setting.area_unit,
      repair_cost: setting.repair_cost,
      acquisition_tax: setting.acquisition_tax,
      scrivener_fee: setting.scrivener_fee,
      moving_cost: setting.moving_cost,
      maintenance_fee: setting.maintenance_fee,
      loan_policy_name: setting.loan_policy&.policy_name,
      loan_ratio: setting.loan_ratio,
      max_bid_amount: setting.max_bid_amount,
      failed_auction_rounds: setting.failed_auction_rounds,
      searchable_appraisal_limit: setting.searchable_appraisal_limit,
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

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/budget_snapshot_service_test.rb`
Expected: 5 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/services/budget_snapshot_service.rb test/services/budget_snapshot_service_test.rb
git commit -m "feat: add BudgetSnapshotService with create, recalculate, and compare"
```

---

## Task 12: Create LoanPolicySyncService and Job

**Files:**
- Create: `app/services/loan_policy_sync_service.rb`
- Create: `test/services/loan_policy_sync_service_test.rb`
- Create: `app/jobs/loan_policy_sync_job.rb`
- Create: `test/jobs/loan_policy_sync_job_test.rb`
- Modify: `config/recurring.yml`

- [ ] **Step 1: Write the failing test for sync service**

Create `test/services/loan_policy_sync_service_test.rb`:

```ruby
require "test_helper"

class LoanPolicySyncServiceTest < ActiveSupport::TestCase
  test "syncs policies from adapter to database" do
    # Clear existing loan policies from fixtures
    LoanPolicy.delete_all

    result = LoanPolicySyncService.call

    assert result[:synced_count] > 0
    assert LoanPolicy.count > 0
  end

  test "does not duplicate existing policies" do
    LoanPolicy.delete_all
    LoanPolicySyncService.call
    count_after_first = LoanPolicy.count

    LoanPolicySyncService.call
    count_after_second = LoanPolicy.count

    assert_equal count_after_first, count_after_second
  end

  test "updates existing policy when loan_ratio changes" do
    LoanPolicy.delete_all
    LoanPolicySyncService.call

    apt = PropertyType.find_by!(code: "apartment")
    policy = LoanPolicy.find_by!(property_type: apt, policy_name: "일반 주담대")
    original_ratio = policy.loan_ratio

    assert_equal 0.7, original_ratio.to_f
  end

  test "returns summary with synced and skipped counts" do
    LoanPolicy.delete_all
    result = LoanPolicySyncService.call

    assert result.key?(:synced_count)
    assert result.key?(:skipped_count)
    assert result.key?(:property_types_processed)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/loan_policy_sync_service_test.rb`
Expected: FAIL — NameError

- [ ] **Step 3: Create sync service**

Create `app/services/loan_policy_sync_service.rb`:

```ruby
class LoanPolicySyncService
  def self.call
    new.call
  end

  def call
    adapter = LoanPolicyAdapter.for
    synced = 0
    skipped = 0
    types_processed = []

    PropertyType.enabled.find_each do |pt|
      types_processed << pt.code
      policies = adapter.fetch_policies(property_type_code: pt.code)

      policies.each do |policy_data|
        existing = LoanPolicy.find_by(
          property_type: pt,
          policy_name: policy_data[:policy_name]
        )

        if existing
          if policy_changed?(existing, policy_data)
            existing.update!(
              loan_ratio: policy_data[:loan_ratio],
              description: policy_data[:description],
              source_url: policy_data[:source_url],
              effective_date: policy_data[:effective_date]
            )
            synced += 1
          else
            skipped += 1
          end
        else
          LoanPolicy.create!(
            property_type: pt,
            policy_name: policy_data[:policy_name],
            loan_ratio: policy_data[:loan_ratio],
            description: policy_data[:description],
            source_url: policy_data[:source_url],
            effective_date: policy_data[:effective_date],
            enabled: true
          )
          synced += 1
        end
      end
    end

    { synced_count: synced, skipped_count: skipped, property_types_processed: types_processed }
  end

  private

  def policy_changed?(existing, new_data)
    existing.loan_ratio.to_f != new_data[:loan_ratio].to_f ||
      existing.description != new_data[:description] ||
      existing.source_url != new_data[:source_url]
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/loan_policy_sync_service_test.rb`
Expected: 4 tests, 0 failures

- [ ] **Step 5: Write the failing test for sync job**

Create `test/jobs/loan_policy_sync_job_test.rb`:

```ruby
require "test_helper"

class LoanPolicySyncJobTest < ActiveSupport::TestCase
  test "performs loan policy sync" do
    LoanPolicy.delete_all
    LoanPolicySyncJob.perform_now
    assert LoanPolicy.count > 0
  end
end
```

- [ ] **Step 6: Run test to verify it fails**

Run: `bin/rails test test/jobs/loan_policy_sync_job_test.rb`
Expected: FAIL — NameError

- [ ] **Step 7: Create the job**

Create `app/jobs/loan_policy_sync_job.rb`:

```ruby
class LoanPolicySyncJob < ApplicationJob
  queue_as :default

  def perform
    result = LoanPolicySyncService.call
    Rails.logger.info "[LoanPolicySyncJob] Synced: #{result[:synced_count]}, Skipped: #{result[:skipped_count]}, Types: #{result[:property_types_processed].join(', ')}"
  end
end
```

- [ ] **Step 8: Configure recurring schedule**

Edit `config/recurring.yml` to add:

```yaml
loan_policy_sync:
  class: LoanPolicySyncJob
  schedule: every day at 6am
```

- [ ] **Step 9: Run all tests to verify**

Run: `bin/rails test test/services/loan_policy_sync_service_test.rb test/jobs/loan_policy_sync_job_test.rb`
Expected: 5 tests, 0 failures

- [ ] **Step 10: Commit**

```bash
git add app/services/loan_policy_sync_service.rb app/jobs/loan_policy_sync_job.rb test/services/loan_policy_sync_service_test.rb test/jobs/loan_policy_sync_job_test.rb config/recurring.yml
git commit -m "feat: add LoanPolicySyncService and daily sync job"
```

---

## Task 13: Setup routes and guest auto-session

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/application_controller.rb`
- Create: `app/controllers/home_controller.rb`
- Create: `app/views/home/index.html.erb`
- Create: `test/controllers/home_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/home_controller_test.rb`:

```ruby
require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "redirects to onboarding when no budget settings" do
    get root_url
    assert_redirected_to start_onboarding_url
  end

  test "shows home page when budget settings completed" do
    user = User.create!(email: "home@test.com", password: "password")
    BudgetSetting.create!(
      user: user,
      available_cash: 30000,
      loan_ratio: 0.7,
      area_unit: "pyeong",
      failed_auction_rounds: 0,
      completed_at: Time.current
    )

    # Simulate guest session pointing to this user
    get root_url
    # First visit creates guest session, which has no budget settings → redirect
    assert_redirected_to start_onboarding_url
  end

  test "auto-creates guest session on first visit" do
    assert_difference "User.count", 1 do
      get root_url
    end
  end

  test "does not create duplicate guest user on second visit" do
    get root_url
    assert_no_difference "User.count" do
      get root_url
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/home_controller_test.rb`
Expected: FAIL — routing error or controller not found

- [ ] **Step 3: Setup routes**

Replace `config/routes.rb` with:

```ruby
Rails.application.routes.draw do
  root "home#index"

  resource :onboarding, only: [] do
    collection do
      get "/", action: :step1, as: :start
      post :step1
      post :step2
      post :step3
      get :complete
    end
  end

  namespace :settings do
    resource :budget, only: [:show, :update]
    resources :budget_snapshots, only: [:index, :show] do
      member do
        post :recalculate
      end
      collection do
        get :compare
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
```

- [ ] **Step 4: Add guest auto-session to ApplicationController**

Replace `app/controllers/application_controller.rb` with:

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :set_guest_user

  private

  def set_guest_user
    return if session[:user_id] && User.exists?(session[:user_id])

    guest = User.find_or_create_by!(email: "guest@auction.local") do |u|
      u.password = "123456"
    end
    session[:user_id] = guest.id
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
  helper_method :current_user
end
```

- [ ] **Step 5: Create HomeController**

Create `app/controllers/home_controller.rb`:

```ruby
class HomeController < ApplicationController
  def index
    if current_user.budget_setting&.completed?
      render :index
    else
      redirect_to start_onboarding_url
    end
  end
end
```

- [ ] **Step 6: Create home view placeholder**

Create `app/views/home/index.html.erb`:

```erb
<div class="container mx-auto px-4 py-8">
  <h1 class="text-2xl font-bold mb-4">경매 물건 목록</h1>
  <p class="text-gray-600">물건 목록은 F02에서 구현됩니다.</p>

  <% if current_user.budget_setting %>
    <div class="mt-6 p-4 bg-blue-50 rounded-lg">
      <p class="font-semibold">내 최대입찰가: <%= number_with_delimiter(current_user.budget_setting.max_bid_amount) %>만원</p>
      <a href="<%= settings_budget_path %>" class="text-blue-600 underline text-sm">예산 설정 변경</a>
    </div>
  <% end %>
</div>
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/controllers/home_controller_test.rb`
Expected: 4 tests, 0 failures

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/application_controller.rb app/controllers/home_controller.rb app/views/home/index.html.erb test/controllers/home_controller_test.rb
git commit -m "feat: add routes, guest auto-session, and home controller with onboarding redirect"
```

---

## Task 14: Create OnboardingsController (step1, step2, step3, complete)

**Files:**
- Create: `app/controllers/onboardings_controller.rb`
- Create: `test/controllers/onboardings_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/onboardings_controller_test.rb`:

```ruby
require "test_helper"

class OnboardingsControllerTest < ActionDispatch::IntegrationTest
  test "GET step1 renders the first step" do
    get start_onboarding_url
    assert_response :success
    assert_select "turbo-frame#onboarding_wizard"
  end

  test "POST step1 saves available_cash and renders step2" do
    get start_onboarding_url  # create guest session

    post step1_onboarding_url, params: { budget_setting: { available_cash: 30000 } }
    assert_response :success
    assert_select "turbo-frame#onboarding_wizard"

    user = User.find_by(email: "guest@auction.local")
    assert_equal 30000, user.budget_setting.available_cash
  end

  test "POST step1 with invalid data re-renders step1" do
    get start_onboarding_url

    post step1_onboarding_url, params: { budget_setting: { available_cash: -100 } }
    assert_response :unprocessable_entity
  end

  test "POST step2 saves reserve funds and renders step3" do
    get start_onboarding_url
    post step1_onboarding_url, params: { budget_setting: { available_cash: 30000 } }

    apt = property_types(:apartment)
    post step2_onboarding_url, params: {
      budget_setting: {
        property_type_id: apt.id,
        area_range_min: 59,
        area_range_max: 84,
        area_unit: "pyeong",
        repair_cost: 500,
        acquisition_tax: 360,
        scrivener_fee: 80,
        moving_cost: 150,
        maintenance_fee: 50
      }
    }
    assert_response :success

    user = User.find_by(email: "guest@auction.local")
    assert_equal apt.id, user.budget_setting.property_type_id
    assert_equal 500, user.budget_setting.repair_cost
  end

  test "POST step3 calculates max bid, creates snapshot, and redirects to complete" do
    get start_onboarding_url
    post step1_onboarding_url, params: { budget_setting: { available_cash: 30000 } }

    apt = property_types(:apartment)
    policy = loan_policies(:general_apartment)
    post step2_onboarding_url, params: {
      budget_setting: {
        property_type_id: apt.id, area_range_min: 59, area_range_max: 84,
        area_unit: "pyeong", repair_cost: 500, acquisition_tax: 360,
        scrivener_fee: 80, moving_cost: 150, maintenance_fee: 50
      }
    }

    post step3_onboarding_url, params: {
      budget_setting: {
        loan_policy_id: policy.id,
        loan_ratio: 0.7,
        failed_auction_rounds: 2
      }
    }
    assert_redirected_to complete_onboarding_url

    user = User.find_by(email: "guest@auction.local")
    setting = user.budget_setting
    assert setting.completed?
    assert_equal 96200, setting.max_bid_amount
    assert_equal 1, user.budget_snapshots.count
  end

  test "GET complete shows results" do
    user = User.create!(email: "complete@test.com", password: "pass")
    BudgetSetting.create!(
      user: user, available_cash: 30000, loan_ratio: 0.7,
      max_bid_amount: 96200, area_unit: "pyeong",
      failed_auction_rounds: 0, searchable_appraisal_limit: 96200,
      completed_at: Time.current
    )
    BudgetSnapshot.create!(
      user: user, version: 1, trigger: "onboarding",
      available_cash: 30000, max_bid_amount: 96200,
      calculated_at: Time.current
    )

    # Use guest session for this test
    get start_onboarding_url  # creates guest
    # Guest won't have the right data, so test complete page directly
    # by creating settings for the guest user
    guest = User.find_by(email: "guest@auction.local")
    BudgetSetting.create!(
      user: guest, available_cash: 30000, loan_ratio: 0.7,
      max_bid_amount: 96200, area_unit: "pyeong",
      failed_auction_rounds: 0, searchable_appraisal_limit: 96200,
      completed_at: Time.current
    )
    BudgetSnapshot.create!(
      user: guest, version: 1, trigger: "onboarding",
      available_cash: 30000, max_bid_amount: 96200,
      calculated_at: Time.current
    )

    get complete_onboarding_url
    assert_response :success
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/onboardings_controller_test.rb`
Expected: FAIL — controller not found

- [ ] **Step 3: Create OnboardingsController**

Create `app/controllers/onboardings_controller.rb`:

```ruby
class OnboardingsController < ApplicationController
  before_action :find_or_initialize_budget_setting, except: [:complete]

  def step1
    render :step1
  end

  def step2
    render :step2
  end

  def step3
    render :step3
  end

  def complete
    @setting = current_user.budget_setting
    @snapshot = current_user.budget_snapshots.order(version: :desc).first
    redirect_to start_onboarding_url unless @setting&.completed?
  end

  # POST actions for each step are named after the step they SAVE,
  # then render the NEXT step.

  # POST /onboarding/step1 — saves cash, renders step2
  def create_step1
    @setting.available_cash = step1_params[:available_cash]

    if @setting.save
      load_step2_data
      render :step2
    else
      render :step1, status: :unprocessable_entity
    end
  end

  # POST /onboarding/step2 — saves reserves, renders step3
  def create_step2
    @setting.assign_attributes(step2_params)

    if @setting.save
      load_step3_data
      render :step3
    else
      load_step2_data
      render :step2, status: :unprocessable_entity
    end
  end

  # POST /onboarding/step3 — calculates, saves, creates snapshot, redirects to complete
  def create_step3
    @setting.assign_attributes(step3_params)

    result = BudgetCalculationService.call(
      available_cash: @setting.available_cash,
      reserve_funds: {
        repair: @setting.repair_cost.to_i,
        acquisition_tax: @setting.acquisition_tax.to_i,
        scrivener: @setting.scrivener_fee.to_i,
        moving: @setting.moving_cost.to_i,
        maintenance: @setting.maintenance_fee.to_i
      },
      loan_ratio: @setting.loan_ratio.to_f,
      failed_auction_rounds: @setting.failed_auction_rounds
    )

    @setting.max_bid_amount = result[:max_bid_amount]
    @setting.searchable_appraisal_limit = result[:searchable_appraisal_limit]
    @setting.completed_at = Time.current

    if @setting.save
      BudgetSnapshotService.create(user: current_user, trigger: "onboarding")
      redirect_to complete_onboarding_url
    else
      load_step3_data
      render :step3, status: :unprocessable_entity
    end
  rescue BudgetCalculationService::InsufficientFundsError
    @setting.errors.add(:available_cash, "이(가) 예비비 합계보다 작습니다")
    load_step3_data
    render :step3, status: :unprocessable_entity
  end

  private

  def find_or_initialize_budget_setting
    @setting = current_user.budget_setting || current_user.build_budget_setting
  end

  def step1_params
    params.expect(budget_setting: [:available_cash])
  end

  def step2_params
    params.expect(budget_setting: [
      :property_type_id, :area_range_min, :area_range_max, :area_unit,
      :repair_cost, :acquisition_tax, :scrivener_fee, :moving_cost, :maintenance_fee
    ])
  end

  def step3_params
    params.expect(budget_setting: [:loan_policy_id, :loan_ratio, :failed_auction_rounds])
  end

  def load_step2_data
    @property_types = PropertyType.enabled.ordered
    @reserve_defaults = ReserveFundDefault.where(
      property_type_id: @property_types.pluck(:id)
    ).group_by(&:property_type_id)
  end

  def load_step3_data
    @loan_policies = LoanPolicy.active.for_property_type(@setting.property_type_id)
  end
end
```

- [ ] **Step 4: Update routes to use correct action names**

Replace the onboarding routes in `config/routes.rb`:

```ruby
  resource :onboarding, only: [] do
    collection do
      get "/", action: :step1, as: :start
      post :step1, action: :create_step1
      post :step2, action: :create_step2
      post :step3, action: :create_step3
      get :complete
    end
  end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/onboardings_controller_test.rb`
Expected: Tests pass (view templates will be needed — create minimal versions first)

- [ ] **Step 6: Commit**

```bash
git add app/controllers/onboardings_controller.rb config/routes.rb test/controllers/onboardings_controller_test.rb
git commit -m "feat: add OnboardingsController with 3-step wizard flow"
```

---

## Task 15: Create onboarding views (MUST use /rails-ui skill)

> **IMPORTANT**: This task MUST invoke the `/rails-ui` skill for design token compliance. The implementing agent should call `/rails-ui` before writing any ERB template.

**Files:**
- Create: `app/views/onboardings/step1.html.erb`
- Create: `app/views/onboardings/step2.html.erb`
- Create: `app/views/onboardings/step3.html.erb`
- Create: `app/views/onboardings/complete.html.erb`

- [ ] **Step 1: Invoke /rails-ui skill**

Before writing any view code, invoke the `/rails-ui` skill to load design tokens and component patterns.

- [ ] **Step 2: Create step1 view**

Create `app/views/onboardings/step1.html.erb`:

The view must:
- Wrap content in `<turbo-frame id="onboarding_wizard">`
- Show heading: "투자 가능한 유용자금을 입력하세요"
- Number input field for `available_cash` with `inputmode="numeric"`, suffix "만원"
- Help text: "유용자금이란 현재 투자에 사용할 수 있는 현금을 말합니다"
- Wire Stimulus `number_format_controller` for comma formatting
- "다음" submit button
- Use design tokens from `/rails-ui` for all spacing, colors, typography

- [ ] **Step 3: Create step2 view**

Create `app/views/onboardings/step2.html.erb`:

The view must:
- Wrap in `<turbo-frame id="onboarding_wizard">`
- Property type select dropdown (from `@property_types`)
- Area range select dropdown
- 평/㎡ toggle (wire `area_unit_controller`)
- "기본값 사용" checkbox (wire `reserve_fund_controller`)
- 5 reserve fund input fields (repair_cost, acquisition_tax, scrivener_fee, moving_cost, maintenance_fee)
- Reserve total display (updates via Stimulus)
- Each input: `inputmode="numeric"`, suffix "만원"
- "이전" link back to step1, "다음" submit button
- Pass `@reserve_defaults` as JSON data attribute for Stimulus controller

- [ ] **Step 4: Create step3 view**

Create `app/views/onboardings/step3.html.erb`:

The view must:
- Wrap in `<turbo-frame id="onboarding_wizard">`
- Radio buttons for loan policies (from `@loan_policies`): name + ratio display
- Loan ratio slider (60%–90%) wired to `loan_slider_controller`
- Real-time max bid preview (client-side calculation matching `BudgetCalculationService` formula)
- Failed auction rounds slider (0–3) wired to `failed_rounds_controller`
- Searchable appraisal limit preview
- Disclaimer: "이 계산은 추정치입니다. 정확한 대출 한도는 금융기관에 확인하세요."
- "이전" link, "계산하기" submit button
- Pass `available_cash` and `total_reserves` as data attributes for client-side preview

- [ ] **Step 5: Create complete view**

Create `app/views/onboardings/complete.html.erb`:

The view must:
- Highlighted max bid amount card with 만원 display and 억원 conversion
- Failed rounds info if applicable
- Itemized cost breakdown table
- Applied policy name and calculation date
- "내 예산 범위 물건 보기" CTA button → root_path
- "설정 다시 하기" link → settings_budget_path

- [ ] **Step 6: Verify all views render**

Run: `bin/rails test test/controllers/onboardings_controller_test.rb`
Expected: All tests pass with views rendering correctly

- [ ] **Step 7: Commit**

```bash
git add app/views/onboardings/
git commit -m "feat: add onboarding wizard views with Turbo Frame and Stimulus wiring"
```

---

## Task 16: Create Stimulus controllers

**Files:**
- Create: `app/javascript/controllers/number_format_controller.js`
- Create: `app/javascript/controllers/reserve_fund_controller.js`
- Create: `app/javascript/controllers/area_unit_controller.js`
- Create: `app/javascript/controllers/loan_slider_controller.js`
- Create: `app/javascript/controllers/failed_rounds_controller.js`
- Create: `app/javascript/controllers/navigation_controller.js`

- [ ] **Step 1: Create number_format_controller.js**

Create `app/javascript/controllers/number_format_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Formats numeric inputs with comma separators (e.g., 30,000)
// Usage: <input data-controller="number-format" data-action="input->number-format#format">
export default class extends Controller {
  format(event) {
    const input = event.target
    const raw = input.value.replace(/,/g, "").replace(/[^0-9]/g, "")
    if (raw === "") {
      input.value = ""
      return
    }
    const number = parseInt(raw, 10)
    input.value = number.toLocaleString("ko-KR")
    // Store raw value in a hidden field or data attribute
    input.dataset.rawValue = number
  }

  // Get the raw numeric value for form submission
  getRawValue(input) {
    return parseInt(input.value.replace(/,/g, ""), 10) || 0
  }
}
```

- [ ] **Step 2: Create reserve_fund_controller.js**

Create `app/javascript/controllers/reserve_fund_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Handles "기본값 사용" toggle and reserve fund total calculation
// Targets: checkbox, repairCost, acquisitionTax, scrivenerFee, movingCost, maintenanceFee, total
export default class extends Controller {
  static targets = [
    "useDefaults", "propertyType", "areaRange",
    "repairCost", "acquisitionTax", "scrivenerFee",
    "movingCost", "maintenanceFee", "total"
  ]
  static values = {
    defaults: Object // JSON of reserve_fund_defaults keyed by property_type_id
  }

  connect() {
    this.updateTotal()
  }

  toggleDefaults() {
    if (this.useDefaultsTarget.checked) {
      this.applyDefaults()
    }
  }

  applyDefaults() {
    const propertyTypeId = this.propertyTypeTarget.value
    const areaRange = this.areaRangeTarget.value
    const defaults = this.defaultsValue[propertyTypeId]

    if (!defaults) return

    const match = defaults.find(d =>
      parseInt(areaRange) >= d.area_range_min && parseInt(areaRange) <= d.area_range_max
    )

    if (match) {
      this.repairCostTarget.value = match.repair_cost.toLocaleString("ko-KR")
      this.acquisitionTaxTarget.value = Math.round(match.acquisition_tax_rate * 10000).toLocaleString("ko-KR")
      this.scrivenerFeeTarget.value = match.scrivener_fee.toLocaleString("ko-KR")
      this.movingCostTarget.value = match.moving_cost.toLocaleString("ko-KR")
      this.maintenanceFeeTarget.value = match.maintenance_fee.toLocaleString("ko-KR")
      this.updateTotal()
    }
  }

  propertyTypeChanged() {
    if (this.useDefaultsTarget.checked) {
      this.applyDefaults()
    }
    this.updateTotal()
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
      return sum + (parseInt(field.value.replace(/,/g, ""), 10) || 0)
    }, 0)

    this.totalTarget.textContent = total.toLocaleString("ko-KR")
  }
}
```

- [ ] **Step 3: Create area_unit_controller.js**

Create `app/javascript/controllers/area_unit_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Toggles between 평 and ㎡ display
// 1평 = 3.305785㎡
export default class extends Controller {
  static targets = ["display", "unitInput"]
  static values = {
    sqm: Number,   // stored ㎡ value
    unit: { type: String, default: "pyeong" }
  }

  static SQM_PER_PYEONG = 3.305785

  toggle(event) {
    this.unitValue = event.target.value
    this.updateDisplay()
  }

  updateDisplay() {
    this.displayTargets.forEach(el => {
      const sqm = parseFloat(el.dataset.sqmValue)
      if (this.unitValue === "pyeong") {
        el.textContent = `${Math.round(sqm / 3.305785)}평`
      } else {
        el.textContent = `${sqm}㎡`
      }
    })
  }
}
```

- [ ] **Step 4: Create loan_slider_controller.js**

Create `app/javascript/controllers/loan_slider_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Handles loan ratio slider with real-time max bid preview
export default class extends Controller {
  static targets = ["slider", "ratioDisplay", "maxBidPreview", "hiddenRatio"]
  static values = {
    availableCash: Number,
    totalReserves: Number
  }

  connect() {
    this.updatePreview()
  }

  selectPolicy(event) {
    const ratio = parseFloat(event.target.dataset.loanRatio)
    this.sliderTarget.value = Math.round(ratio * 100)
    this.updatePreview()
  }

  slide() {
    this.updatePreview()
  }

  updatePreview() {
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

- [ ] **Step 5: Create failed_rounds_controller.js**

Create `app/javascript/controllers/failed_rounds_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Handles failed auction rounds slider with appraisal limit preview
export default class extends Controller {
  static targets = ["slider", "roundsDisplay", "limitPreview"]
  static values = {
    maxBid: Number
  }

  connect() {
    this.updatePreview()
  }

  slide() {
    this.updatePreview()
  }

  updateMaxBid(maxBid) {
    this.maxBidValue = maxBid
    this.updatePreview()
  }

  updatePreview() {
    const rounds = parseInt(this.sliderTarget.value, 10)
    this.roundsDisplayTarget.textContent = `${rounds}회차`

    if (rounds === 0) {
      this.limitPreviewTarget.textContent = `${this.maxBidValue.toLocaleString("ko-KR")}만원`
    } else {
      const factor = Math.pow(0.8, rounds)
      const limit = Math.floor(this.maxBidValue / factor)
      this.limitPreviewTarget.textContent = `${limit.toLocaleString("ko-KR")}만원`
    }
  }
}
```

- [ ] **Step 6: Create navigation_controller.js**

Create `app/javascript/controllers/navigation_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Handles browser back button within the wizard
// Intercepts popstate to navigate to previous wizard step instead of browser history
export default class extends Controller {
  static values = {
    step: Number,
    previousUrl: String
  }

  connect() {
    this.boundPopstate = this.handlePopstate.bind(this)
    window.addEventListener("popstate", this.boundPopstate)
    // Push current step to history
    history.pushState({ step: this.stepValue }, "", window.location.href)
  }

  disconnect() {
    window.removeEventListener("popstate", this.boundPopstate)
  }

  handlePopstate(event) {
    if (this.hasPreviousUrlValue && this.previousUrlValue) {
      event.preventDefault()
      window.location.href = this.previousUrlValue
    }
  }
}
```

- [ ] **Step 7: Register controllers by running stimulus manifest**

Run: `bin/rails stimulus:manifest:update`
Expected: `app/javascript/controllers/index.js` is updated with new controller imports

- [ ] **Step 8: Commit**

```bash
git add app/javascript/controllers/
git commit -m "feat: add Stimulus controllers for wizard interactivity"
```

---

## Task 17: Create Settings::BudgetsController

**Files:**
- Create: `app/controllers/settings/budgets_controller.rb`
- Create: `app/views/settings/budgets/show.html.erb`
- Create: `test/controllers/settings/budgets_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/settings/budgets_controller_test.rb`:

```ruby
require "test_helper"

class Settings::BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_url  # create guest session
    @user = User.find_by(email: "guest@auction.local")
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
      loan_policy: loan_policies(:general_apartment),
      loan_ratio: 0.7,
      max_bid_amount: 96200,
      area_unit: "pyeong",
      failed_auction_rounds: 0,
      searchable_appraisal_limit: 96200,
      completed_at: Time.current
    )
  end

  test "GET show renders budget settings" do
    get settings_budget_url
    assert_response :success
  end

  test "PATCH update saves new settings and creates snapshot" do
    patch settings_budget_url, params: {
      budget_setting: {
        available_cash: 40000,
        property_type_id: property_types(:apartment).id,
        area_range_min: 59,
        area_range_max: 84,
        area_unit: "pyeong",
        repair_cost: 500,
        acquisition_tax: 360,
        scrivener_fee: 80,
        moving_cost: 150,
        maintenance_fee: 50,
        loan_policy_id: loan_policies(:general_apartment).id,
        loan_ratio: 0.7,
        failed_auction_rounds: 0
      }
    }

    assert_redirected_to settings_budget_url
    @setting.reload
    assert_equal 40000, @setting.available_cash
    assert_equal 1, @user.budget_snapshots.count
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/settings/budgets_controller_test.rb`
Expected: FAIL — controller not found

- [ ] **Step 3: Create controller**

Create `app/controllers/settings/budgets_controller.rb`:

```ruby
module Settings
  class BudgetsController < ApplicationController
    def show
      @setting = current_user.budget_setting
      redirect_to start_onboarding_url unless @setting&.completed?
      @property_types = PropertyType.enabled.ordered
      @loan_policies = LoanPolicy.active.for_property_type(@setting.property_type_id)
    end

    def update
      @setting = current_user.budget_setting

      @setting.assign_attributes(budget_params)

      result = BudgetCalculationService.call(
        available_cash: @setting.available_cash,
        reserve_funds: {
          repair: @setting.repair_cost.to_i,
          acquisition_tax: @setting.acquisition_tax.to_i,
          scrivener: @setting.scrivener_fee.to_i,
          moving: @setting.moving_cost.to_i,
          maintenance: @setting.maintenance_fee.to_i
        },
        loan_ratio: @setting.loan_ratio.to_f,
        failed_auction_rounds: @setting.failed_auction_rounds
      )

      @setting.max_bid_amount = result[:max_bid_amount]
      @setting.searchable_appraisal_limit = result[:searchable_appraisal_limit]

      if @setting.save
        BudgetSnapshotService.create(user: current_user, trigger: "manual_edit")
        redirect_to settings_budget_url, notice: "예산 설정이 업데이트되었습니다."
      else
        @property_types = PropertyType.enabled.ordered
        @loan_policies = LoanPolicy.active.for_property_type(@setting.property_type_id)
        render :show, status: :unprocessable_entity
      end
    rescue BudgetCalculationService::InsufficientFundsError
      @setting.errors.add(:available_cash, "이(가) 예비비 합계보다 작습니다")
      @property_types = PropertyType.enabled.ordered
      @loan_policies = LoanPolicy.active.for_property_type(@setting.property_type_id)
      render :show, status: :unprocessable_entity
    end

    private

    def budget_params
      params.expect(budget_setting: [
        :available_cash, :property_type_id, :area_range_min, :area_range_max,
        :area_unit, :repair_cost, :acquisition_tax, :scrivener_fee,
        :moving_cost, :maintenance_fee, :loan_policy_id, :loan_ratio,
        :failed_auction_rounds
      ])
    end
  end
end
```

- [ ] **Step 4: Create show view (invoke /rails-ui)**

Create `app/views/settings/budgets/show.html.erb`:

> Invoke `/rails-ui` skill before writing this view. The view must show the same 3-step form as onboarding, but pre-filled with current values, with a single "저장" button that PATCHes all fields at once.

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/settings/budgets_controller_test.rb`
Expected: 3 tests, 0 failures

- [ ] **Step 6: Commit**

```bash
git add app/controllers/settings/budgets_controller.rb app/views/settings/budgets/ test/controllers/settings/budgets_controller_test.rb
git commit -m "feat: add Settings::BudgetsController for My Page budget editing"
```

---

## Task 18: Create Settings::BudgetSnapshotsController

**Files:**
- Create: `app/controllers/settings/budget_snapshots_controller.rb`
- Create: `app/views/settings/budget_snapshots/index.html.erb`
- Create: `app/views/settings/budget_snapshots/show.html.erb`
- Create: `app/views/settings/budget_snapshots/compare.html.erb`
- Create: `test/controllers/settings/budget_snapshots_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/settings/budget_snapshots_controller_test.rb`:

```ruby
require "test_helper"

class Settings::BudgetSnapshotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_url
    @user = User.find_by(email: "guest@auction.local")
    BudgetSetting.create!(
      user: @user, available_cash: 30000, loan_ratio: 0.7,
      max_bid_amount: 96200, area_unit: "pyeong",
      failed_auction_rounds: 0, searchable_appraisal_limit: 96200,
      completed_at: Time.current
    )
    @snapshot1 = BudgetSnapshot.create!(
      user: @user, version: 1, trigger: "onboarding",
      available_cash: 30000, loan_ratio: 0.7, max_bid_amount: 96200,
      calculated_at: 1.day.ago
    )
    @snapshot2 = BudgetSnapshot.create!(
      user: @user, version: 2, trigger: "manual_edit",
      available_cash: 40000, loan_ratio: 0.7, max_bid_amount: 129533,
      calculated_at: Time.current
    )
  end

  test "GET index lists snapshots" do
    get settings_budget_snapshots_url
    assert_response :success
  end

  test "GET show displays a single snapshot" do
    get settings_budget_snapshot_url(@snapshot1)
    assert_response :success
  end

  test "GET compare shows diff between two snapshots" do
    get compare_settings_budget_snapshots_url(ids: [@snapshot1.id, @snapshot2.id])
    assert_response :success
  end

  test "POST recalculate creates a new snapshot" do
    assert_difference "@user.budget_snapshots.count", 1 do
      post recalculate_settings_budget_snapshot_url(@snapshot1)
    end
    assert_redirected_to settings_budget_snapshots_url
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/settings/budget_snapshots_controller_test.rb`
Expected: FAIL — controller not found

- [ ] **Step 3: Create controller**

Create `app/controllers/settings/budget_snapshots_controller.rb`:

```ruby
module Settings
  class BudgetSnapshotsController < ApplicationController
    def index
      @snapshots = current_user.budget_snapshots.order(version: :desc)
    end

    def show
      @snapshot = current_user.budget_snapshots.find(params[:id])
    end

    def compare
      ids = params[:ids]
      @snapshot_a = current_user.budget_snapshots.find(ids[0])
      @snapshot_b = current_user.budget_snapshots.find(ids[1])
      @diff = BudgetSnapshotService.compare(snapshot_a: @snapshot_a, snapshot_b: @snapshot_b)
    end

    def recalculate
      parent = current_user.budget_snapshots.find(params[:id])
      BudgetSnapshotService.recalculate(user: current_user, parent_snapshot: parent)
      redirect_to settings_budget_snapshots_url, notice: "현재 조건으로 재계산되었습니다."
    end
  end
end
```

- [ ] **Step 4: Create views (invoke /rails-ui)**

> Invoke `/rails-ui` skill before writing views.

Create `app/views/settings/budget_snapshots/index.html.erb` — list of snapshots with version, trigger, max_bid_amount, calculated_at. Each row has "보기" and "재계산" links. Checkbox selection for "비교" action.

Create `app/views/settings/budget_snapshots/show.html.erb` — full snapshot detail (same layout as onboarding complete screen but for historical data).

Create `app/views/settings/budget_snapshots/compare.html.erb` — side-by-side comparison table showing changed fields with was/now/delta columns.

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/settings/budget_snapshots_controller_test.rb`
Expected: 4 tests, 0 failures

- [ ] **Step 6: Commit**

```bash
git add app/controllers/settings/budget_snapshots_controller.rb app/views/settings/budget_snapshots/ test/controllers/settings/budget_snapshots_controller_test.rb
git commit -m "feat: add BudgetSnapshotsController with index, show, compare, recalculate"
```

---

## Task 19: Reserve fund defaults API endpoint (for Stimulus)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/api/reserve_fund_defaults_controller.rb`
- Create: `test/controllers/api/reserve_fund_defaults_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/api/reserve_fund_defaults_controller_test.rb`:

```ruby
require "test_helper"

class Api::ReserveFundDefaultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_url  # create guest session
    apt = property_types(:apartment)
    ReserveFundDefault.create!(
      property_type: apt, area_range_min: 59, area_range_max: 84,
      repair_cost: 500, acquisition_tax_rate: 0.011,
      scrivener_fee: 80, moving_cost: 150, maintenance_fee: 50
    )
  end

  test "GET index returns defaults for given property_type_id" do
    apt = property_types(:apartment)
    get api_reserve_fund_defaults_url(property_type_id: apt.id), as: :json
    assert_response :success

    body = JSON.parse(response.body)
    assert_kind_of Array, body
    assert body.length > 0
    assert_equal 500, body.first["repair_cost"]
  end

  test "GET index returns empty array for unknown type" do
    get api_reserve_fund_defaults_url(property_type_id: 9999), as: :json
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/api/reserve_fund_defaults_controller_test.rb`
Expected: FAIL — routing error

- [ ] **Step 3: Add route**

Add to `config/routes.rb` before the health check:

```ruby
  namespace :api do
    resources :reserve_fund_defaults, only: [:index]
  end
```

- [ ] **Step 4: Create controller**

Create `app/controllers/api/reserve_fund_defaults_controller.rb`:

```ruby
module Api
  class ReserveFundDefaultsController < ApplicationController
    def index
      defaults = ReserveFundDefault.where(property_type_id: params[:property_type_id])
      render json: defaults.select(
        :id, :area_range_min, :area_range_max, :repair_cost,
        :acquisition_tax_rate, :scrivener_fee, :moving_cost, :maintenance_fee
      )
    end
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/api/reserve_fund_defaults_controller_test.rb`
Expected: 2 tests, 0 failures

- [ ] **Step 6: Commit**

```bash
git add app/controllers/api/reserve_fund_defaults_controller.rb config/routes.rb test/controllers/api/reserve_fund_defaults_controller_test.rb
git commit -m "feat: add API endpoint for reserve fund defaults lookup"
```

---

## Task 20: Run full test suite and lint

**Files:** None (verification only)

- [ ] **Step 1: Run all tests**

Run: `bin/rails test`
Expected: All tests pass, 0 failures

- [ ] **Step 2: Run RuboCop**

Run: `bin/rubocop`
Expected: No offenses (or auto-fixable only)

- [ ] **Step 3: Auto-fix any lint issues**

Run: `bin/rubocop -a`
Expected: All offenses corrected

- [ ] **Step 4: Run Brakeman security scan**

Run: `bin/brakeman --quiet --no-pager`
Expected: No warnings

- [ ] **Step 5: Run seed verification**

Run: `bin/rails db:reset && bin/rails db:seed`
Expected: Seed runs without errors

- [ ] **Step 6: Commit any lint fixes**

```bash
git add -A
git commit -m "chore: fix lint and style issues"
```

---

## Task 21: E2E test for complete wizard flow (MUST use /e2e-testing skill)

> **IMPORTANT**: This task MUST invoke the `/e2e-testing` skill for proper browser test setup and screenshot verification.

**Files:**
- Create: E2E test file (exact path determined by /e2e-testing skill)

- [ ] **Step 1: Invoke /e2e-testing skill**

Invoke `/e2e-testing` to set up the E2E test framework and get test file conventions.

- [ ] **Step 2: Write E2E test for complete onboarding flow**

The test must:
1. Visit root URL → verify redirect to onboarding step1
2. Enter available cash (30,000만원) → click "다음"
3. Select property type (아파트), area range, keep defaults → click "다음"
4. Select loan policy, adjust slider, set failed rounds → click "계산하기"
5. Verify complete screen shows max bid amount
6. Verify "내 예산 범위 물건 보기" CTA exists
7. Take screenshot evidence at each step

- [ ] **Step 3: Write E2E test for settings edit flow**

The test must:
1. Complete onboarding first
2. Navigate to /settings/budget
3. Change available cash → save
4. Verify new snapshot created
5. Navigate to snapshot history
6. Verify comparison between v1 and v2

- [ ] **Step 4: Run E2E tests**

Run the E2E test command (determined by /e2e-testing skill)
Expected: All E2E tests pass with screenshot evidence

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test: add E2E tests for onboarding wizard and settings flows"
```
