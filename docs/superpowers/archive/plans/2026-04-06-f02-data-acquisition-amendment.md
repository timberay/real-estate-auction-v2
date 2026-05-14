# F02 Data Acquisition Amendment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor F02 to support per-user property management and analysis: UserProperty join table, user-scoped check results, case number input, and deterministic mock data generation.

**Architecture:** Add `UserProperty` join table for per-user safety ratings. Add `user_id` to `PropertyCheckResult` for per-user analysis. Remove `user_id` and `safety_rating` from `Property` (now shared data). Enhance mock adapters with deterministic random generation. Add case-number-based property addition flow.

**Tech Stack:** Rails 8.1, SQLite, ViewComponent, Stimulus, Minitest

**Spec:** `docs/superpowers/specs/2026-04-06-f02-data-acquisition-amendment.md`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `db/migrate/TIMESTAMP_create_user_properties.rb` | New join table |
| Create | `db/migrate/TIMESTAMP_add_user_to_property_check_results.rb` | Add user_id, reindex |
| Create | `db/migrate/TIMESTAMP_remove_user_columns_from_properties.rb` | Drop user_id, safety_rating |
| Create | `app/models/user_property.rb` | Join model with safety_rating enum |
| Modify | `app/models/property.rb` | Remove user/rating, add user_properties |
| Modify | `app/models/property_check_result.rb` | Add belongs_to :user, update uniqueness |
| Modify | `app/models/user.rb` | Add user_properties, properties, check_results |
| Modify | `app/services/auto_check_runner.rb` | Accept user: param |
| Modify | `app/services/property_analysis_service.rb` | Accept user: param |
| Modify | `app/services/safety_rating_service.rb` | Write to UserProperty |
| Modify | `app/adapters/mock_court_auction_adapter.rb` | Random data fallback |
| Modify | `app/adapters/mock_building_ledger_adapter.rb` | Random data fallback |
| Modify | `app/controllers/properties_controller.rb` | Add create, user-scope index/show |
| Modify | `app/controllers/analyses/start_controller.rb` | Pass user to service |
| Modify | `app/controllers/analyses/manual_inputs_controller.rb` | Scope to user |
| Modify | `app/controllers/analyses/results_controller.rb` | Scope to user |
| Modify | `app/controllers/analyses/ratings_controller.rb` | Pass user to service |
| Modify | `app/views/properties/index.html.erb` | Add case number form, user-scoped list |
| Modify | `app/views/properties/show.html.erb` | Read rating from user_property |
| Modify | `app/components/property_card_component.rb` | Accept rating param |
| Modify | `app/components/property_card_component.html.erb` | Use rating param |
| Modify | `config/routes.rb` | Add :create to properties |
| Create | `test/models/user_property_test.rb` | Model tests |
| Create | `test/fixtures/user_properties.yml` | Test fixtures |
| Modify | `test/fixtures/properties.yml` | Remove safety_rating, user_id |
| Modify | `test/fixtures/property_check_results.yml` | Add user references |
| Modify | All existing F02 tests | User-scoping updates |

---

### Task 1: Database Migrations

**Files:**
- Create: `db/migrate/TIMESTAMP_create_user_properties.rb`
- Create: `db/migrate/TIMESTAMP_add_user_to_property_check_results.rb`
- Create: `db/migrate/TIMESTAMP_remove_user_columns_from_properties.rb`

- [ ] **Step 1: Generate the three migrations**

```bash
bin/rails generate migration CreateUserProperties user:references property:references safety_rating:integer analyzed_at:datetime
bin/rails generate migration AddUserToPropertyCheckResults user:references
bin/rails generate migration RemoveUserColumnsFromProperties
```

- [ ] **Step 2: Edit CreateUserProperties migration**

```ruby
class CreateUserProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :user_properties do |t|
      t.references :user, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.integer :safety_rating
      t.datetime :analyzed_at

      t.timestamps
    end

    add_index :user_properties, [:user_id, :property_id], unique: true
  end
end
```

- [ ] **Step 3: Edit AddUserToPropertyCheckResults migration**

This migration must: add user_id (nullable first), backfill existing rows to guest user, then add NOT NULL, and replace the unique index.

```ruby
class AddUserToPropertyCheckResults < ActiveRecord::Migration[8.1]
  def up
    add_reference :property_check_results, :user, null: true, foreign_key: true

    # Backfill existing rows to guest user
    guest = User.find_by(email: "guest@auction.local")
    if guest
      execute "UPDATE property_check_results SET user_id = #{guest.id} WHERE user_id IS NULL"
    end

    change_column_null :property_check_results, :user_id, false

    # Replace unique index
    remove_index :property_check_results, name: "idx_check_results_property_item"
    add_index :property_check_results, [:property_id, :checklist_item_id, :user_id],
              unique: true, name: "idx_check_results_property_item_user"
  end

  def down
    remove_index :property_check_results, name: "idx_check_results_property_item_user"
    add_index :property_check_results, [:property_id, :checklist_item_id],
              unique: true, name: "idx_check_results_property_item"
    remove_reference :property_check_results, :user
  end
end
```

- [ ] **Step 4: Edit RemoveUserColumnsFromProperties migration**

```ruby
class RemoveUserColumnsFromProperties < ActiveRecord::Migration[8.1]
  def up
    # Migrate existing safety_rating data to user_properties before dropping
    execute <<~SQL
      INSERT INTO user_properties (user_id, property_id, safety_rating, created_at, updated_at)
      SELECT user_id, id, safety_rating, created_at, updated_at
      FROM properties
      WHERE user_id IS NOT NULL
      ON CONFLICT (user_id, property_id) DO NOTHING
    SQL

    remove_index :properties, :safety_rating, if_exists: true
    remove_index :properties, :user_id, if_exists: true
    remove_column :properties, :safety_rating, :integer
    remove_column :properties, :user_id, :integer
  end

  def down
    add_column :properties, :safety_rating, :integer
    add_column :properties, :user_id, :integer
    add_index :properties, :safety_rating
    add_index :properties, :user_id
  end
end
```

- [ ] **Step 5: Run migrations**

Run: `bin/rails db:migrate`
Expected: 3 migrations applied successfully

- [ ] **Step 6: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "feat(f02): add user_properties table, add user_id to check_results, remove user columns from properties"
```

---

### Task 2: UserProperty Model + Tests (RED → GREEN)

**Files:**
- Create: `app/models/user_property.rb`
- Create: `test/models/user_property_test.rb`
- Create: `test/fixtures/user_properties.yml`

- [ ] **Step 1: Write failing tests**

```ruby
# test/models/user_property_test.rb
require "test_helper"

class UserPropertyTest < ActiveSupport::TestCase
  test "valid with user and property" do
    up = UserProperty.new(user: users(:guest), property: properties(:safe_apartment))
    assert up.valid?
  end

  test "requires user" do
    up = UserProperty.new(property: properties(:safe_apartment))
    assert_not up.valid?
  end

  test "requires property" do
    up = UserProperty.new(user: users(:guest))
    assert_not up.valid?
  end

  test "user and property combination must be unique" do
    UserProperty.create!(user: users(:guest), property: properties(:safe_apartment))
    duplicate = UserProperty.new(user: users(:guest), property: properties(:safe_apartment))
    assert_not duplicate.valid?
  end

  test "safety_rating enum values" do
    up = UserProperty.new(user: users(:guest), property: properties(:unanalyzed_officetel))
    up.safety_rating = :safe
    assert up.safe?
    up.safety_rating = :caution
    assert up.caution?
    up.safety_rating = :danger
    assert up.danger?
  end

  test "safety_rating defaults to nil" do
    up = UserProperty.new(user: users(:guest), property: properties(:unanalyzed_officetel))
    assert_nil up.safety_rating
  end
end
```

- [ ] **Step 2: Create fixtures**

```yaml
# test/fixtures/user_properties.yml
guest_safe_apartment:
  user: guest
  property: safe_apartment
  safety_rating: 0

guest_risky_villa:
  user: guest
  property: risky_villa
  safety_rating: 2

guest_unanalyzed_officetel:
  user: guest
  property: unanalyzed_officetel
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/models/user_property_test.rb`
Expected: FAIL — `NameError: uninitialized constant UserProperty`

- [ ] **Step 4: Create the model**

```ruby
# app/models/user_property.rb
class UserProperty < ApplicationRecord
  belongs_to :user
  belongs_to :property

  enum :safety_rating, { safe: 0, caution: 1, danger: 2 }

  validates :user_id, uniqueness: { scope: :property_id }
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/models/user_property_test.rb`
Expected: all 6 tests PASS

- [ ] **Step 6: Commit**

```bash
git add app/models/user_property.rb test/models/user_property_test.rb test/fixtures/user_properties.yml
git commit -m "feat(f02): add UserProperty model with validations and tests"
```

---

### Task 3: Update Existing Models + Fix Fixtures

**Files:**
- Modify: `app/models/property.rb`
- Modify: `app/models/property_check_result.rb`
- Modify: `app/models/user.rb`
- Modify: `test/fixtures/properties.yml`
- Modify: `test/fixtures/property_check_results.yml`

- [ ] **Step 1: Update Property model**

Replace entire content of `app/models/property.rb`:

```ruby
class Property < ApplicationRecord
  has_many :user_properties, dependent: :destroy
  has_many :users, through: :user_properties
  has_many :property_check_results, dependent: :destroy
  has_many :checklist_items, through: :property_check_results

  validates :case_number, presence: true, uniqueness: true
end
```

Removed: `belongs_to :user, optional: true`, `enum :safety_rating`.

- [ ] **Step 2: Update PropertyCheckResult model**

Replace entire content of `app/models/property_check_result.rb`:

```ruby
class PropertyCheckResult < ApplicationRecord
  belongs_to :property
  belongs_to :checklist_item
  belongs_to :user

  enum :source_type, { auto: 0, manual: 1 }

  validates :property_id, uniqueness: { scope: [:checklist_item_id, :user_id] }
end
```

Added: `belongs_to :user`. Changed uniqueness scope to include `:user_id`.

- [ ] **Step 3: Update User model**

Add associations to `app/models/user.rb` (keep existing content, add new lines):

```ruby
class User < ApplicationRecord
  has_secure_password

  has_one :budget_setting, dependent: :destroy
  has_many :budget_snapshots, dependent: :destroy
  has_many :user_properties, dependent: :destroy
  has_many :properties, through: :user_properties
  has_many :property_check_results, dependent: :destroy
end
```

- [ ] **Step 4: Fix properties fixture**

Replace `test/fixtures/properties.yml` — remove `safety_rating` values:

```yaml
safe_apartment:
  case_number: "2026타경10001"
  court_name: "서울중앙지방법원"
  property_type: "아파트"
  address: "서울특별시 강남구 역삼동 100-1"
  appraisal_price: 80000
  min_bid_price: 56000
  status: "진행중"

risky_villa:
  case_number: "2026타경10002"
  court_name: "수원지방법원"
  property_type: "빌라"
  address: "경기도 수원시 영통구 200-2"
  appraisal_price: 30000
  min_bid_price: 21000
  status: "진행중"

unanalyzed_officetel:
  case_number: "2026타경10003"
  court_name: "인천지방법원"
  property_type: "오피스텔"
  address: "인천광역시 연수구 300-3"
  appraisal_price: 25000
  min_bid_price: 17500
  status: "진행중"
```

- [ ] **Step 5: Fix property_check_results fixture**

Replace `test/fixtures/property_check_results.yml` — add `user: guest`:

```yaml
safe_apartment_rights_011:
  property: safe_apartment
  checklist_item: rights_011
  user: guest
  source_type: 0
  has_risk: false

risky_villa_rights_011:
  property: risky_villa
  checklist_item: rights_011
  user: guest
  source_type: 0
  has_risk: true
  resolvable: false
```

- [ ] **Step 6: Fix model tests**

Update `test/models/property_test.rb` — remove safety_rating tests, add new association tests. Read the current file first to identify exact lines to change. Key changes:
- Remove tests referencing `property.safety_rating`, `property.safe?`, `property.caution?`, `property.danger?`
- Add test for `has_many :user_properties` association
- Remove any test referencing `belongs_to :user`

Update `test/models/property_check_result_test.rb` — add user to uniqueness test:
- Change uniqueness test to create records with `user: users(:guest)`
- Add test: duplicate with same user fails, different user succeeds

- [ ] **Step 7: Run model tests**

Run: `bin/rails test test/models/`
Expected: all model tests PASS

- [ ] **Step 8: Commit**

```bash
git add app/models/ test/models/ test/fixtures/
git commit -m "refactor(f02): update models for per-user analysis — Property shared, CheckResult user-scoped"
```

---

### Task 4: Update Services (RED → GREEN)

**Files:**
- Modify: `app/services/auto_check_runner.rb`
- Modify: `app/services/property_analysis_service.rb`
- Modify: `app/services/safety_rating_service.rb`

- [ ] **Step 1: Update existing service tests to pass user param**

Update `test/services/auto_check_runner_test.rb`:
- All calls to `AutoCheckRunner.call(property:)` → `AutoCheckRunner.call(property:, user: users(:guest))`

Update `test/services/property_analysis_service_test.rb`:
- All calls to `PropertyAnalysisService.call(property:)` → `PropertyAnalysisService.call(property:, user: users(:guest))`

Update `test/services/safety_rating_service_test.rb`:
- All calls to `SafetyRatingService.call(property:)` → `SafetyRatingService.call(property:, user: users(:guest))`
- Change assertions from `@property.reload.safety_rating` to `UserProperty.find_by(user: users(:guest), property: @property).safety_rating`
- Ensure a UserProperty exists before calling the service (e.g., `UserProperty.create!(user: users(:guest), property: @property)`)

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/`
Expected: FAIL — services don't accept `user:` param yet

- [ ] **Step 3: Update AutoCheckRunner**

```ruby
class AutoCheckRunner
  DETECTION_RULES = {
    # ... unchanged ...
  }.freeze

  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    raw = @property.raw_data || {}

    ChecklistItem.ordered.map do |item|
      rule = DETECTION_RULES[item.code]
      result = @property.property_check_results.find_or_initialize_by(
        checklist_item: item, user: @user
      )

      if rule.nil?
        result.assign_attributes(source_type: nil, has_risk: nil)
      else
        detected = rule.call(raw)
        if detected.nil?
          result.assign_attributes(source_type: nil, has_risk: nil)
        else
          result.assign_attributes(source_type: "auto", has_risk: detected)
        end
      end

      result.save!
      result
    end
  end
end
```

Key change: `self.call` and `initialize` accept `user:`. Line 41 `find_or_initialize_by` includes `user: @user`.

- [ ] **Step 4: Update PropertyAnalysisService**

```ruby
class PropertyAnalysisService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    results = AutoCheckRunner.call(property: @property, user: @user)
    pending = results.select { |r| r.source_type.nil? }

    { results: results, pending_manual_items: pending }
  end
end
```

- [ ] **Step 5: Update SafetyRatingService**

```ruby
class SafetyRatingService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    results = @property.property_check_results.where(has_risk: true, user: @user)

    rating = if results.exists?(resolvable: false)
      :danger
    elsif results.any?
      :caution
    else
      :safe
    end

    user_property = UserProperty.find_by!(user: @user, property: @property)
    user_property.update!(safety_rating: rating, analyzed_at: Time.current)
    rating
  end
end
```

Key change: queries scoped to `user: @user`, writes to `UserProperty` instead of `Property`.

- [ ] **Step 6: Run service tests**

Run: `bin/rails test test/services/`
Expected: all PASS

- [ ] **Step 7: Commit**

```bash
git add app/services/ test/services/
git commit -m "refactor(f02): add user param to services — AutoCheckRunner, AnalysisService, RatingService"
```

---

### Task 5: Mock Adapter Enhancement (RED → GREEN)

**Files:**
- Modify: `app/adapters/mock_court_auction_adapter.rb`
- Modify: `app/adapters/mock_building_ledger_adapter.rb`
- Create: `test/adapters/mock_court_auction_adapter_test.rb`
- Create: `test/adapters/mock_building_ledger_adapter_test.rb`

- [ ] **Step 1: Write failing tests for random data generation**

```ruby
# test/adapters/mock_court_auction_adapter_test.rb
require "test_helper"

class MockCourtAuctionAdapterTest < ActiveSupport::TestCase
  setup do
    @adapter = MockCourtAuctionAdapter.new
  end

  test "returns predefined data for known case numbers" do
    data = @adapter.fetch_data(case_number: "2026타경10001")
    assert_equal "서울중앙지방법원", data[:court_name]
    assert_equal "아파트", data[:property_type]
  end

  test "generates data for unknown case numbers" do
    data = @adapter.fetch_data(case_number: "2026타경99999")
    assert_not_nil data
    assert_equal "2026타경99999", data[:case_number]
    assert_includes ["아파트", "빌라", "오피스텔"], data[:property_type]
    assert data[:appraisal_price].is_a?(Integer)
    assert data[:appraisal_price] > 0
  end

  test "generates deterministic data for same case number" do
    data1 = @adapter.fetch_data(case_number: "2026타경55555")
    data2 = @adapter.fetch_data(case_number: "2026타경55555")
    assert_equal data1, data2
  end

  test "generates different data for different case numbers" do
    data1 = @adapter.fetch_data(case_number: "2026타경55555")
    data2 = @adapter.fetch_data(case_number: "2026타경66666")
    assert_not_equal data1[:address], data2[:address]
  end
end
```

```ruby
# test/adapters/mock_building_ledger_adapter_test.rb
require "test_helper"

class MockBuildingLedgerAdapterTest < ActiveSupport::TestCase
  setup do
    @adapter = MockBuildingLedgerAdapter.new
  end

  test "returns predefined data for known case numbers" do
    data = @adapter.fetch_data(case_number: "2026타경10001")
    assert_equal "아파트", data[:usage_type]
  end

  test "generates data for unknown case numbers" do
    data = @adapter.fetch_data(case_number: "2026타경99999")
    assert_not_nil data
    assert_includes ["아파트", "빌라", "오피스텔", "근린생활시설", "사무소"], data[:usage_type]
    assert_includes [true, false], data[:violation_flag]
  end

  test "generates deterministic data for same case number" do
    data1 = @adapter.fetch_data(case_number: "2026타경55555")
    data2 = @adapter.fetch_data(case_number: "2026타경55555")
    assert_equal data1, data2
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/adapters/`
Expected: FAIL — unknown case numbers return nil

- [ ] **Step 3: Implement random data generation in MockCourtAuctionAdapter**

```ruby
class MockCourtAuctionAdapter < CourtAuctionAdapter
  MOCK_DATA = {
    # ... existing 3 entries unchanged ...
  }.freeze

  COURTS = [
    "서울중앙지방법원", "서울남부지방법원", "서울동부지방법원",
    "수원지방법원", "인천지방법원", "대전지방법원",
    "대구지방법원", "부산지방법원", "광주지방법원"
  ].freeze

  ADDRESSES = {
    "서울중앙지방법원" => ["서울특별시 강남구 역삼동", "서울특별시 서초구 반포동", "서울특별시 송파구 잠실동"],
    "서울남부지방법원" => ["서울특별시 영등포구 여의도동", "서울특별시 양천구 목동"],
    "서울동부지방법원" => ["서울특별시 강동구 천호동", "서울특별시 광진구 구의동"],
    "수원지방법원" => ["경기도 수원시 영통구", "경기도 수원시 팔달구"],
    "인천지방법원" => ["인천광역시 연수구", "인천광역시 남동구"],
    "대전지방법원" => ["대전광역시 서구 둔산동", "대전광역시 유성구"],
    "대구지방법원" => ["대구광역시 수성구", "대구광역시 달서구"],
    "부산지방법원" => ["부산광역시 해운대구", "부산광역시 수영구"],
    "광주지방법원" => ["광주광역시 서구", "광주광역시 북구"]
  }.freeze

  PROPERTY_TYPES = ["아파트", "빌라", "오피스텔"].freeze

  def fetch_data(case_number:)
    MOCK_DATA[case_number] || generate_random_property(case_number)
  end

  private

  def generate_random_property(case_number)
    rng = Random.new(case_number.bytes.sum)

    court = COURTS[rng.rand(COURTS.size)]
    addresses = ADDRESSES[court]
    address = "#{addresses[rng.rand(addresses.size)]} #{rng.rand(1..500)}-#{rng.rand(1..30)}"
    property_type = PROPERTY_TYPES[rng.rand(PROPERTY_TYPES.size)]
    appraisal = (rng.rand(50..1500) * 100)
    bid_ratio = [0.64, 0.72, 0.80].sample(random: rng)

    has_tenants = rng.rand < 0.4
    tenants = if has_tenants
      [{ name: "임차인#{rng.rand(1..99)}",
         deposit: rng.rand < 0.2 ? nil : rng.rand(1000..10000),
         move_in_date: "202#{rng.rand(3..5)}-#{format('%02d', rng.rand(1..12))}-#{format('%02d', rng.rand(1..28))}",
         dividend_requested: rng.rand < 0.6 }]
    else
      []
    end

    {
      case_number: case_number,
      court_name: court,
      property_type: property_type,
      address: address,
      appraisal_price: appraisal,
      min_bid_price: (appraisal * bid_ratio).to_i,
      remarks: rng.rand < 0.15 ? "유치권 신고 있음" : "해당사항 없음",
      non_extinguished_rights: rng.rand < 0.1 ? ["전세권"] : [],
      tenants: tenants,
      separate_land_registry: rng.rand < 0.05,
      lien_reported: rng.rand < 0.1,
      use_approval: rng.rand < 0.95,
      wall_partition_issue: rng.rand < 0.05,
      is_partial_share: rng.rand < 0.08
    }
  end
end
```

- [ ] **Step 4: Implement random data generation in MockBuildingLedgerAdapter**

```ruby
class MockBuildingLedgerAdapter < BuildingLedgerAdapter
  MOCK_DATA = {
    # ... existing 3 entries unchanged ...
  }.freeze

  USAGE_TYPES = ["아파트", "빌라", "오피스텔", "근린생활시설", "사무소"].freeze

  def fetch_data(case_number:)
    MOCK_DATA[case_number] || generate_random_building_data(case_number)
  end

  private

  def generate_random_building_data(case_number)
    rng = Random.new(case_number.bytes.sum + 1)

    room_count = [1, 1, 2, 3, 3, 3, 4][rng.rand(7)]
    floor_options = (1..20).map { |n| "#{n}층" } + ["반지하"]
    year = rng.rand(2005..2025)
    month = format("%02d", rng.rand(1..12))

    {
      usage_type: USAGE_TYPES[rng.rand(USAGE_TYPES.size)],
      violation_flag: rng.rand < 0.1,
      completion_date: "#{year}-#{month}-#{format('%02d', rng.rand(1..28))}",
      room_count: room_count,
      floor_info: floor_options[rng.rand(floor_options.size)],
      parking_per_unit: (rng.rand(2..15) / 10.0).round(1),
      total_units: rng.rand(10..300)
    }
  end
end
```

- [ ] **Step 5: Run adapter tests**

Run: `bin/rails test test/adapters/`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add app/adapters/ test/adapters/
git commit -m "feat(f02): add deterministic random data generation to mock adapters"
```

---

### Task 6: Controller Updates — PropertiesController

**Files:**
- Modify: `app/controllers/properties_controller.rb`
- Modify: `config/routes.rb`
- Modify: `test/controllers/properties_controller_test.rb`

- [ ] **Step 1: Update tests for user-scoped index, show, and new create action**

Read `test/controllers/properties_controller_test.rb` first, then replace with updated tests that:
- Test index returns only current user's properties (via user_properties)
- Test index filters by `UserProperty.safety_rating`
- Test create with new case number → creates Property + UserProperty
- Test create with existing case number → creates only UserProperty
- Test create with already-added case number → flash message, no duplicate
- Test show loads `@user_property`

- [ ] **Step 2: Update routes**

In `config/routes.rb`, change:
```ruby
resources :properties, only: [ :index, :show ] do
```
to:
```ruby
resources :properties, only: [ :index, :show, :create ] do
```

- [ ] **Step 3: Update PropertiesController**

```ruby
class PropertiesController < ApplicationController
  def index
    @user_properties = current_user.user_properties
      .includes(:property)
      .order(created_at: :desc)
    @user_properties = @user_properties.where(safety_rating: params[:safety_rating]) if params[:safety_rating].present?
    @properties = @user_properties.map(&:property)
  end

  def show
    @property = Property.find(params[:id])
    @user_property = current_user.user_properties.find_by(property: @property)
    @check_results = @property.property_check_results
      .where(user: current_user)
      .includes(:checklist_item)
      .order("checklist_items.position")
  end

  def create
    case_number = params[:case_number]&.strip

    if case_number.blank?
      redirect_to properties_path, alert: "경매번호를 입력해주세요."
      return
    end

    property = Property.find_by(case_number: case_number)

    if property
      if current_user.user_properties.exists?(property: property)
        redirect_to properties_path, notice: "이미 내 목록에 있는 물건입니다."
      else
        current_user.user_properties.create!(property: property)
        redirect_to properties_path, notice: "이미 등록된 물건입니다. 내 목록에 추가했습니다."
      end
    else
      property = PropertyDataSyncService.call(case_number: case_number)
      if property
        current_user.user_properties.create!(property: property)
        redirect_to properties_path, notice: "물건이 추가되었습니다."
      else
        redirect_to properties_path, alert: "해당 경매번호의 물건을 찾을 수 없습니다."
      end
    end
  end
end
```

- [ ] **Step 4: Run controller tests**

Run: `bin/rails test test/controllers/properties_controller_test.rb`
Expected: all PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/properties_controller.rb config/routes.rb test/controllers/properties_controller_test.rb
git commit -m "feat(f02): add property creation via case number, user-scoped index and show"
```

---

### Task 7: Controller Updates — Analysis Controllers

**Files:**
- Modify: `app/controllers/analyses/start_controller.rb`
- Modify: `app/controllers/analyses/manual_inputs_controller.rb`
- Modify: `app/controllers/analyses/results_controller.rb`
- Modify: `app/controllers/analyses/ratings_controller.rb`

- [ ] **Step 1: Update StartController**

```ruby
module Analyses
  class StartController < ApplicationController
    def create
      @property = Property.find(params[:property_id])
      result = PropertyAnalysisService.call(property: @property, user: current_user)

      if result[:pending_manual_items].any?
        redirect_to edit_property_analyses_manual_input_url(@property)
      else
        redirect_to edit_property_analyses_result_url(@property)
      end
    end
  end
end
```

- [ ] **Step 2: Update ManualInputsController**

```ruby
module Analyses
  class ManualInputsController < ApplicationController
    def edit
      @property = Property.find(params[:property_id])
      @pending_results = @property.property_check_results
        .where(source_type: nil, user: current_user)
        .includes(:checklist_item)
        .order("checklist_items.position")
    end

    def update
      @property = Property.find(params[:property_id])

      if params[:check_results].present?
        params[:check_results].each do |id, values|
          result = @property.property_check_results.where(user: current_user).find(id)
          result.update!(
            source_type: "manual",
            manual_value: values[:manual_value],
            has_risk: values[:has_risk] == "true"
          )
        end
      end

      redirect_to edit_property_analyses_result_url(@property)
    end
  end
end
```

- [ ] **Step 3: Update ResultsController**

```ruby
module Analyses
  class ResultsController < ApplicationController
    def edit
      @property = Property.find(params[:property_id])
      @results_by_axis = @property.property_check_results
        .where(user: current_user)
        .includes(:checklist_item)
        .order("checklist_items.position")
        .group_by { |r| r.checklist_item.risk_axis }
    end

    def update
      @property = Property.find(params[:property_id])

      if params[:resolutions].present?
        params[:resolutions].each do |id, values|
          result = @property.property_check_results.where(user: current_user).find(id)
          result.update!(
            resolvable: values[:resolvable] == "true",
            resolution_note: values[:resolution_note]
          )
        end
      end

      redirect_to property_analyses_rating_url(@property)
    end
  end
end
```

- [ ] **Step 4: Update RatingsController**

```ruby
module Analyses
  class RatingsController < ApplicationController
    def show
      @property = Property.find(params[:property_id])
      @rating = SafetyRatingService.call(property: @property, user: current_user)
      @risk_results = @property.property_check_results
        .where(has_risk: true, user: current_user)
        .includes(:checklist_item)
        .order("checklist_items.position")
    end
  end
end
```

- [ ] **Step 5: Update analysis controller tests and integration test**

Read and update `test/controllers/analyses/` tests and `test/integration/property_analysis_flow_test.rb`:
- Ensure `UserProperty` exists before analysis starts
- Scope all check result queries to user
- Assert on `UserProperty` safety_rating instead of `Property` safety_rating

- [ ] **Step 6: Run all analysis tests**

Run: `bin/rails test test/controllers/analyses/ test/integration/`
Expected: all PASS

- [ ] **Step 7: Commit**

```bash
git add app/controllers/analyses/ test/controllers/analyses/ test/integration/
git commit -m "refactor(f02): add user scoping to all analysis controllers"
```

---

### Task 8: View Updates

**Files:**
- Modify: `app/views/properties/index.html.erb`
- Modify: `app/views/properties/show.html.erb`
- Modify: `app/components/property_card_component.rb`
- Modify: `app/components/property_card_component.html.erb`

- [ ] **Step 1: Update PropertyCardComponent to accept rating param**

```ruby
# app/components/property_card_component.rb
# frozen_string_literal: true

class PropertyCardComponent < ViewComponent::Base
  def initialize(property:, rating: nil)
    @property = property
    @rating = rating
  end

  private

  def formatted_price(amount)
    return "—" unless amount
    number_to_currency(amount, unit: "", precision: 0, delimiter: ",") + "만원"
  end
end
```

```erb
<%# app/components/property_card_component.html.erb %>
<%= render CardComponent.new do |card| %>
  <div class="flex items-start justify-between">
    <div class="min-w-0 flex-1">
      <div class="flex items-center gap-2">
        <%= link_to @property.case_number, property_path(@property),
            class: "text-base font-semibold text-slate-900 dark:text-slate-100 hover:text-blue-600 dark:hover:text-blue-400" %>
        <%= render SafetyBadgeComponent.new(rating: @rating) %>
      </div>
      <p class="mt-1 text-sm text-slate-600 dark:text-slate-400 truncate"><%= @property.address %></p>
      <div class="mt-2 flex items-center gap-4 text-sm text-slate-500 dark:text-slate-400">
        <span>감정가 <%= formatted_price(@property.appraisal_price) %></span>
        <span>최저가 <%= formatted_price(@property.min_bid_price) %></span>
      </div>
    </div>
  </div>
<% end %>
```

- [ ] **Step 2: Update properties/index.html.erb**

```erb
<%# app/views/properties/index.html.erb %>
<div class="space-y-6">
  <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
    <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">물건 목록</h1>
    <div data-controller="property-filter" class="flex items-center gap-2">
      <%= form_with url: properties_path, method: :get, data: { property_filter_target: "form" }, class: "flex items-center gap-2" do %>
        <%= select_tag :safety_rating,
            options_for_select([["전체", ""], ["Safe", "safe"], ["Caution", "caution"], ["Danger", "danger"]], params[:safety_rating]),
            class: "rounded-md border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-200 text-sm",
            data: { property_filter_target: "ratingSelect", action: "change->property-filter#filter" } %>
        <button type="button" data-action="click->property-filter#safeOnly"
                class="inline-flex items-center rounded-md bg-green-50 px-3 py-1.5 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20 hover:bg-green-100 dark:bg-green-900/30 dark:text-green-400 dark:ring-green-400/20 dark:hover:bg-green-900/50">
          Safe만 보기
        </button>
      <% end %>
    </div>
  </div>

  <%# Case number input form %>
  <%= form_with url: properties_path, method: :post, class: "flex items-center gap-2" do |f| %>
    <%= f.text_field :case_number,
        placeholder: "경매번호를 입력하세요 (예: 2026타경1234)",
        class: "flex-1 rounded-md border-slate-300 dark:border-slate-600 dark:bg-slate-700 dark:text-slate-200 text-sm focus:ring-blue-500 focus:border-blue-500" %>
    <%= render ButtonComponent.new(type: "submit", icon: "plus", variant: :primary) { "물건 추가" } %>
  <% end %>

  <% if @user_properties.any? %>
    <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
      <% @user_properties.each do |user_property| %>
        <%= render PropertyCardComponent.new(property: user_property.property, rating: user_property.safety_rating) %>
      <% end %>
    </div>
  <% else %>
    <%= render EmptyStateComponent.new(
      icon: "magnifying-glass",
      title: "아직 추가한 물건이 없습니다",
      description: "경매번호를 입력하여 물건을 추가하세요."
    ) %>
  <% end %>
</div>
```

- [ ] **Step 3: Update properties/show.html.erb**

Replace `@property.safety_rating` with `@user_property&.safety_rating`:

```erb
<%# app/views/properties/show.html.erb %>
<div class="space-y-6">
  <div class="flex items-center gap-2">
    <%= link_to "← 목록", properties_path, class: "text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300" %>
  </div>

  <%= render CardComponent.new(title: @property.case_number) do |card| %>
    <div class="space-y-3">
      <div class="flex items-center gap-2">
        <%= render SafetyBadgeComponent.new(rating: @user_property&.safety_rating) %>
        <% if @property.court_name.present? %>
          <span class="text-sm text-slate-500 dark:text-slate-400"><%= @property.court_name %></span>
        <% end %>
      </div>
      <p class="text-sm text-slate-700 dark:text-slate-300"><%= @property.address %></p>
      <div class="grid grid-cols-2 gap-4 text-sm">
        <div>
          <span class="text-slate-500 dark:text-slate-400">감정가</span>
          <p class="font-semibold text-slate-900 dark:text-slate-100"><%= number_to_currency(@property.appraisal_price, unit: "", precision: 0, delimiter: ",") %>만원</p>
        </div>
        <div>
          <span class="text-slate-500 dark:text-slate-400">최저매각가</span>
          <p class="font-semibold text-slate-900 dark:text-slate-100"><%= number_to_currency(@property.min_bid_price, unit: "", precision: 0, delimiter: ",") %>만원</p>
        </div>
      </div>
    </div>
  <% end %>

  <%= turbo_frame_tag "analysis_flow" do %>
    <% if @user_property&.safety_rating.present? %>
      <div class="text-center space-y-3">
        <p class="text-sm text-slate-600 dark:text-slate-400">이미 분석이 완료되었습니다.</p>
        <div class="flex justify-center gap-3">
          <%= button_to "다시 분석하기", property_analyses_start_path(@property), method: :post,
              class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
          <%= link_to "결과 보기", property_analyses_rating_path(@property),
              class: "inline-flex items-center rounded-md bg-slate-100 dark:bg-slate-700 px-4 py-2 text-sm font-medium text-slate-700 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-600" %>
        </div>
      </div>
    <% else %>
      <div class="text-center">
        <%= button_to "안전 분석 시작", property_analyses_start_path(@property), method: :post,
            class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
      </div>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 4: Update component tests**

Update `test/components/property_card_component_test.rb` to pass `rating:` parameter.

- [ ] **Step 5: Run all tests**

Run: `bin/rails test`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add app/views/properties/ app/components/property_card_component* test/components/
git commit -m "feat(f02): add case number input form, user-scoped property list and ratings"
```

---

## Verification

After all tasks are complete:

1. `bin/rails test` — all tests pass, no regressions
2. `bin/rubocop` — no style violations
3. `bin/dev` — start dev server:
   - Visit `/properties` — empty state with case number input form
   - Enter "2026타경10001" — property added, appears in list
   - Enter same number again — "이미 내 목록에 있는 물건입니다" flash
   - Enter "2026타경99999" — random mock data generated, property added
   - Click property → show page with "안전 분석 시작" button
   - Run analysis → check results scoped to current user
   - Safety rating appears on property card after analysis
   - Filter by safety rating works via UserProperty
