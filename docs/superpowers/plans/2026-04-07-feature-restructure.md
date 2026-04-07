# F02 Property Inspection (6+1 Tab) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the 3-step stepper analysis (17 items, risk-axis grouping) with a 6+1 tab document-based inspection flow (89 items, tab grouping) and integrated rights analysis grade.

**Architecture:** New models `InspectionItem` and `InspectionResult` replace `ChecklistItem` and `PropertyCheckResult`. New services `InspectionRunner` and `InspectionRatingService` replace `AutoCheckRunner` and `SafetyRatingService`. Old `analyses/` namespace replaced by `inspections/` namespace. `RightsAnalysisService` and `RightsAnalysisReport` are retained and rendered in the 최종등급 tab.

**Tech Stack:** Rails 8.1, Hotwire (Turbo Frames + Stimulus), ViewComponent, TailwindCSS, SQLite, Minitest

**Spec:** `docs/superpowers/specs/2026-04-07-feature-restructure-design.md`

---

## File Structure

### New Files
```
db/migrate/TIMESTAMP_create_inspection_items.rb
db/migrate/TIMESTAMP_create_inspection_results.rb
db/migrate/TIMESTAMP_drop_checklist_items.rb
db/migrate/TIMESTAMP_drop_property_check_results.rb
app/models/inspection_item.rb
app/models/inspection_result.rb
app/services/inspection_runner.rb
app/services/inspection_rating_service.rb
app/services/property_inspection_service.rb
app/controllers/inspections/start_controller.rb
app/controllers/inspections/tabs_controller.rb
app/controllers/inspections/grades_controller.rb
app/controllers/inspections/dividends_controller.rb
app/views/inspections/_layout.html.erb
app/views/inspections/tabs/edit.html.erb
app/views/inspections/grades/show.html.erb
app/components/inspection_tabs_component.rb
app/components/inspection_tabs_component.html.erb
app/components/inspection_item_component.rb
app/components/inspection_item_component.html.erb
app/components/inspection_group_component.rb
app/components/inspection_group_component.html.erb
app/components/grade_summary_component.rb
app/components/grade_summary_component.html.erb
app/components/tab_summary_table_component.rb
app/components/tab_summary_table_component.html.erb
app/components/risk_items_list_component.rb
app/components/risk_items_list_component.html.erb
app/components/rights_report_section_component.rb
app/components/rights_report_section_component.html.erb
app/javascript/controllers/inspection_tabs_controller.js
app/javascript/controllers/inspection_item_controller.js
test/fixtures/inspection_items.yml
test/fixtures/inspection_results.yml
test/models/inspection_item_test.rb
test/models/inspection_result_test.rb
test/services/inspection_runner_test.rb
test/services/inspection_rating_service_test.rb
test/services/property_inspection_service_test.rb
test/controllers/inspections/start_controller_test.rb
test/controllers/inspections/tabs_controller_test.rb
test/controllers/inspections/grades_controller_test.rb
test/components/inspection_tabs_component_test.rb
test/components/inspection_item_component_test.rb
test/components/inspection_group_component_test.rb
test/components/grade_summary_component_test.rb
test/components/tab_summary_table_component_test.rb
test/components/risk_items_list_component_test.rb
test/components/rights_report_section_component_test.rb
test/integration/property_inspection_flow_test.rb
```

### Modified Files
```
config/routes.rb
db/seeds.rb
app/models/property.rb
app/services/rights_analysis_service.rb (update reference from checklist_item → inspection_item)
```

### Deleted Files
```
app/models/checklist_item.rb
app/models/property_check_result.rb
app/services/auto_check_runner.rb
app/services/safety_rating_service.rb
app/services/property_analysis_service.rb
app/controllers/analyses/start_controller.rb
app/controllers/analyses/checklists_controller.rb
app/controllers/analyses/ratings_controller.rb
app/controllers/analyses/reports_controller.rb
app/controllers/analyses/results_controller.rb
app/views/analyses/ (entire directory)
app/components/stepper_component.rb
app/components/stepper_component.html.erb
app/components/checklist_group_component.rb
app/components/checklist_group_component.html.erb
app/components/checklist_item_component.rb
app/components/checklist_item_component.html.erb
app/javascript/controllers/stepper_controller.js
app/javascript/controllers/resolution_input_controller.js
test/models/checklist_item_test.rb
test/models/property_check_result_test.rb
test/services/auto_check_runner_test.rb
test/services/safety_rating_service_test.rb
test/services/property_analysis_service_test.rb
test/controllers/analyses/start_controller_test.rb
test/controllers/analyses/checklists_controller_test.rb
test/controllers/analyses/ratings_controller_test.rb
test/controllers/analyses/reports_controller_test.rb
test/components/stepper_component_test.rb
test/components/checklist_group_component_test.rb
test/components/checklist_item_component_test.rb
test/fixtures/checklist_items.yml
test/fixtures/property_check_results.yml
test/integration/property_analysis_flow_test.rb
```

---

## Task 1: Create InspectionItem Model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_inspection_items.rb`
- Create: `app/models/inspection_item.rb`
- Create: `test/fixtures/inspection_items.yml`
- Create: `test/models/inspection_item_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/models/inspection_item_test.rb
require "test_helper"

class InspectionItemTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    item = InspectionItem.new(
      code: "test-001",
      tab: "sale_document",
      tab_position: 1,
      category: "권리분석",
      question: "테스트 질문입니까?",
      priority: "상"
    )
    assert item.valid?
  end

  test "code is required and unique" do
    InspectionItem.create!(code: "unique-001", tab: "sale_document", tab_position: 1, category: "권리분석", question: "Q?", priority: "상")
    dup = InspectionItem.new(code: "unique-001", tab: "sale_document", tab_position: 2, category: "권리분석", question: "Q2?", priority: "상")
    assert_not dup.valid?
  end

  test "tab enum values" do
    item = InspectionItem.new(code: "enum-test", tab: "sale_document", tab_position: 1, category: "C", question: "Q?", priority: "상")
    assert item.sale_document?

    item.tab = "registry"
    assert item.registry?

    item.tab = "building_ledger"
    assert item.building_ledger?

    item.tab = "online"
    assert item.online?

    item.tab = "field_visit"
    assert item.field_visit?

    item.tab = "etc"
    assert item.etc?
  end

  test "question and category are required" do
    item = InspectionItem.new(code: "test-002", tab: "sale_document", tab_position: 1, question: nil, category: nil, priority: "상")
    assert_not item.valid?
    assert_includes item.errors[:question], "can't be blank"
    assert_includes item.errors[:category], "can't be blank"
  end

  test "ordered scope returns items by tab and tab_position" do
    items = InspectionItem.ordered
    prev = nil
    items.each do |item|
      if prev && prev.tab == item.tab
        assert prev.tab_position <= item.tab_position
      end
      prev = item
    end
  end

  test "for_tab scope returns items for a specific tab" do
    sale_items = InspectionItem.for_tab(:sale_document)
    assert sale_items.all?(&:sale_document?)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/inspection_item_test.rb`
Expected: FAIL — `NameError: uninitialized constant InspectionItem`

- [ ] **Step 3: Generate migration**

Run: `bin/rails generate migration CreateInspectionItems`

Edit the generated migration file:

```ruby
class CreateInspectionItems < ActiveRecord::Migration[8.1]
  def change
    create_table :inspection_items do |t|
      t.string  :code,             null: false
      t.integer :tab,              null: false
      t.integer :tab_position,     null: false, default: 0
      t.string  :category,         null: false
      t.text    :question,         null: false
      t.text    :description
      t.json    :logic
      t.string  :data_source_name
      t.string  :priority,         null: false, default: "상"
      t.string  :merged_from
      t.timestamps
    end
    add_index :inspection_items, :code, unique: true
    add_index :inspection_items, [ :tab, :tab_position ]
  end
end
```

- [ ] **Step 4: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 5: Write the model**

```ruby
# app/models/inspection_item.rb
class InspectionItem < ApplicationRecord
  has_many :inspection_results, dependent: :destroy

  enum :tab, {
    sale_document: 0,   # 매각물건명세서
    registry: 1,        # 등기부등본
    building_ledger: 2, # 건축물대장
    online: 3,          # 온라인조회
    field_visit: 4,     # 현장임장
    etc: 5              # 기타
  }

  validates :code, presence: true, uniqueness: true
  validates :tab, presence: true
  validates :question, presence: true
  validates :category, presence: true

  scope :ordered, -> { order(:tab, :tab_position) }
  scope :for_tab, ->(tab) { where(tab: tab).order(:tab_position) }
end
```

- [ ] **Step 6: Create fixtures**

```yaml
# test/fixtures/inspection_items.yml
rights_002:
  code: "rights-002"
  tab: 0
  tab_position: 1
  category: "권리분석"
  question: "매각물건명세서의 '소멸되지 아니하는 것' 비고란에 기재된 인수 권리가 있습니까?"
  description: "법원이 직접 '이 권리는 낙찰자가 떠안는다'고 명시한 것입니다."
  logic: '{"yes": "법원이 인수 권리를 명시했으므로 초보자는 입찰을 피해야 합니다.", "no": "안전합니다."}'
  data_source_name: "매각물건명세서"
  priority: "상"

rights_011:
  code: "rights-011"
  tab: 0
  tab_position: 2
  category: "권리분석"
  question: "매각물건명세서 비고란에 유치권 또는 법정지상권이 적혀 있습니까?"
  description: "유치권은 공사대금 미지급 등으로 점유를 주장하는 것이고, 법정지상권은 토지와 건물 소유자가 달라질 때 발생합니다."
  logic: '{"yes": "인수해야 할 중대 권리가 명시되어 있습니다.", "no": "치명적인 특수 권리가 없습니다."}'
  data_source_name: "매각물건명세서"
  priority: "상"

rights_001:
  code: "rights-001"
  tab: 1
  tab_position: 1
  category: "권리분석"
  question: "등기부에 말소기준권리보다 앞선 '선순위 가처분'이 있습니까?"
  description: "선순위 가처분은 소유권 분쟁 중이라는 뜻입니다."
  logic: '{"yes": "소유권 자체가 바뀔 수 있어 매우 위험합니다.", "no": "가처분 리스크가 없습니다."}'
  data_source_name: "등기부등본"
  priority: "상"

property_004:
  code: "property-004"
  tab: 2
  tab_position: 1
  category: "물건 기본 필터링"
  question: "건축물대장에 '위반건축물'이라고 표시되어 있습니까?"
  description: "위반건축물은 대출 제한 등 심각한 불이익이 있습니다."
  logic: '{"yes": "대출이 안 나오고 이행강제금이 발생합니다.", "no": "위반 사항이 없습니다."}'
  data_source_name: "건축물대장"
  priority: "상"

property_001:
  code: "property-001"
  tab: 3
  tab_position: 1
  category: "물건 기본 필터링"
  question: "해당 물건이 지분 입찰 물건입니까?"
  description: "지분 경매는 완전한 소유권을 취득하지 못합니다."
  logic: '{"yes": "지분만 취득하게 됩니다.", "no": "안전합니다."}'
  data_source_name: "대법원 법원경매정보"
  priority: "상"

inspect_007:
  code: "inspect-007"
  tab: 4
  tab_position: 1
  category: "현장조사·서류검증"
  question: "현장 우편함의 공과금 통지서 수신인이 소유자(채무자) 이름입니까?"
  description: "우편함 확인으로 실제 거주자를 파악할 수 있습니다."
  logic: '{"yes": "소유자가 거주 중일 가능성이 높습니다.", "no": "제3자가 점유 중일 수 있습니다."}'
  data_source_name: "현장 임장"
  priority: "상"

manual_001:
  code: "manual-001"
  tab: 5
  tab_position: 10
  category: "권리분석"
  question: "분묘기지권(묘지 사용 권리)이 존재합니까?"
  description: "분묘기지권은 토지 위에 묘지가 있는 경우 발생합니다."
  logic: '{"yes": "분묘기지권이 있으면 토지 사용에 제한이 있습니다.", "no": "안전합니다."}'
  data_source_name: "수동 입력"
  priority: "상"
```

- [ ] **Step 7: Run tests**

Run: `bin/rails test test/models/inspection_item_test.rb`
Expected: All PASS

- [ ] **Step 8: Commit**

```bash
git add db/migrate/*create_inspection_items* app/models/inspection_item.rb test/models/inspection_item_test.rb test/fixtures/inspection_items.yml
git commit -m "feat: add InspectionItem model with tab-based classification"
```

---

## Task 2: Create InspectionResult Model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_inspection_results.rb`
- Create: `app/models/inspection_result.rb`
- Create: `test/fixtures/inspection_results.yml`
- Create: `test/models/inspection_result_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/models/inspection_result_test.rb
require "test_helper"

class InspectionResultTest < ActiveSupport::TestCase
  test "valid with property, inspection_item, and user" do
    result = InspectionResult.new(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:rights_002),
      user: users(:guest),
      source_type: "auto",
      has_risk: false
    )
    assert result.valid?
  end

  test "property, inspection_item, and user combination must be unique" do
    InspectionResult.create!(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:rights_001),
      user: users(:guest),
      source_type: "auto",
      has_risk: false
    )
    dup = InspectionResult.new(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:rights_001),
      user: users(:guest)
    )
    assert_not dup.valid?
  end

  test "different users can have results for same property and item" do
    InspectionResult.create!(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:rights_001),
      user: users(:guest),
      source_type: "auto",
      has_risk: false
    )
    result = InspectionResult.new(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:rights_001),
      user: users(:budget_user),
      source_type: "auto",
      has_risk: false
    )
    assert result.valid?
  end

  test "source_type enum" do
    result = InspectionResult.new(source_type: "auto")
    assert result.auto?
    result.source_type = "manual"
    assert result.manual?
  end

  test "has_risk nil means unanswered" do
    result = InspectionResult.new(
      property: properties(:safe_apartment),
      inspection_item: inspection_items(:manual_001),
      user: users(:guest)
    )
    assert_nil result.has_risk
    assert_nil result.source_type
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/models/inspection_result_test.rb`
Expected: FAIL — `NameError: uninitialized constant InspectionResult`

- [ ] **Step 3: Generate migration**

Run: `bin/rails generate migration CreateInspectionResults`

Edit the generated migration file:

```ruby
class CreateInspectionResults < ActiveRecord::Migration[8.1]
  def change
    create_table :inspection_results do |t|
      t.references :property,        null: false, foreign_key: true
      t.references :inspection_item, null: false, foreign_key: true
      t.references :user,            null: false, foreign_key: true
      t.integer    :source_type
      t.boolean    :has_risk
      t.boolean    :resolvable
      t.text       :resolution_note
      t.text       :auto_value
      t.text       :manual_value
      t.timestamps
    end
    add_index :inspection_results,
              [ :property_id, :inspection_item_id, :user_id ],
              unique: true,
              name: "idx_inspection_results_unique"
  end
end
```

- [ ] **Step 4: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 5: Write the model**

```ruby
# app/models/inspection_result.rb
class InspectionResult < ApplicationRecord
  belongs_to :property
  belongs_to :inspection_item
  belongs_to :user

  enum :source_type, { auto: 0, manual: 1 }

  validates :property_id, uniqueness: { scope: [ :inspection_item_id, :user_id ] }
end
```

- [ ] **Step 6: Create fixtures**

```yaml
# test/fixtures/inspection_results.yml
safe_apartment_rights_002:
  property: safe_apartment
  inspection_item: rights_002
  user: guest
  source_type: 0
  has_risk: false

safe_apartment_rights_011:
  property: safe_apartment
  inspection_item: rights_011
  user: guest
  source_type: 0
  has_risk: false

risky_villa_rights_011:
  property: risky_villa
  inspection_item: rights_011
  user: guest
  source_type: 0
  has_risk: true
  resolvable: false

manual_unanswered:
  property: safe_apartment
  inspection_item: manual_001
  user: guest

manual_risk:
  property: risky_villa
  inspection_item: manual_001
  user: guest
  source_type: 1
  has_risk: true
  resolvable: true
  resolution_note: "임차인과 협의 완료"
```

- [ ] **Step 7: Update Property model associations**

```ruby
# app/models/property.rb
class Property < ApplicationRecord
  has_many :user_properties, dependent: :destroy
  has_many :users, through: :user_properties
  has_many :inspection_results, dependent: :destroy
  has_many :inspection_items, through: :inspection_results
  has_many :rights_analysis_reports, dependent: :destroy
  validates :case_number, presence: true, uniqueness: true
end
```

- [ ] **Step 8: Run tests**

Run: `bin/rails test test/models/inspection_result_test.rb`
Expected: All PASS

- [ ] **Step 9: Commit**

```bash
git add db/migrate/*create_inspection_results* app/models/inspection_result.rb app/models/property.rb test/models/inspection_result_test.rb test/fixtures/inspection_results.yml
git commit -m "feat: add InspectionResult model with user-scoped uniqueness"
```

---

## Task 3: Create InspectionRunner Service

**Files:**
- Create: `app/services/inspection_runner.rb`
- Create: `test/services/inspection_runner_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/services/inspection_runner_test.rb
require "test_helper"

class InspectionRunnerTest < ActiveSupport::TestCase
  setup do
    @safe_property = PropertyDataSyncService.call(case_number: "2026타경10001")
    @risky_property = PropertyDataSyncService.call(case_number: "2026타경10002")
    @user = users(:guest)
  end

  test "creates InspectionResult for each InspectionItem" do
    results = InspectionRunner.call(property: @safe_property, user: @user)
    assert_equal InspectionItem.count, results.size
  end

  test "auto-detects risks from raw_data when detection rule exists" do
    InspectionRunner.call(property: @risky_property, user: @user)
    item = InspectionItem.find_by(code: "rights-011")
    next unless item
    result = InspectionResult.find_by(property: @risky_property, inspection_item: item, user: @user)
    assert result.auto?
    assert result.has_risk
  end

  test "leaves items without detection rules as unanswered" do
    InspectionRunner.call(property: @safe_property, user: @user)
    item = InspectionItem.find_by(code: "manual-001")
    next unless item
    result = InspectionResult.find_by(property: @safe_property, inspection_item: item, user: @user)
    assert_nil result.source_type
    assert_nil result.has_risk
  end

  test "is idempotent — running twice does not create duplicates" do
    InspectionRunner.call(property: @safe_property, user: @user)
    count_after_first = InspectionResult.where(property: @safe_property, user: @user).count
    InspectionRunner.call(property: @safe_property, user: @user)
    count_after_second = InspectionResult.where(property: @safe_property, user: @user).count
    assert_equal count_after_first, count_after_second
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/inspection_runner_test.rb`
Expected: FAIL — `NameError: uninitialized constant InspectionRunner`

- [ ] **Step 3: Write the service**

```ruby
# app/services/inspection_runner.rb
class InspectionRunner
  # Detection rules keyed by item code.
  # Each rule is a lambda that takes property raw_data and returns true (risk) / false (safe) / nil (skip).
  DETECTION_RULES = {
    # 매각물건명세서 tab
    "rights-002" => ->(raw) { raw.dig("court_auction", "non_extinguished_rights")&.any? },
    "rights-011" => ->(raw) { raw.dig("court_auction", "remarks")&.match?(/유치권|법정지상권/) },
    "rights-005" => ->(raw) { raw.dig("court_auction", "use_approval") == false },
    "rights-003" => ->(raw) { raw.dig("court_auction", "tenants")&.any? },
    "rights-009" => ->(raw) { raw.dig("court_auction", "hug_waiver") == true },
    "rights-006" => ->(raw) {
      tenants = raw.dig("court_auction", "tenants") || []
      tenants.any? { |t| t["dividend_requested"] == false }
    },
    "rights-014" => ->(raw) {
      tenants = raw.dig("court_auction", "tenants") || []
      tenants.any? { |t| t["deposit"].nil? || t["dividend_requested"] == false }
    },
    "property-002" => ->(raw) { raw.dig("court_auction", "wall_partition_issue") == true },
    "rights-016" => ->(raw) {
      tenants = raw.dig("court_auction", "tenants") || []
      base_date = raw.dig("court_auction", "base_right_date")
      return nil unless base_date
      tenants.any? { |t| t["move_in_date"] && t["move_in_date"] < base_date }
    },
    "rights-019" => ->(raw) { raw.dig("court_auction", "separate_land_registry") == true },
    "rights-020" => ->(raw) { raw.dig("court_auction", "lien_reported") == true },
    "property-006" => ->(raw) { raw.dig("court_auction", "property_type") == "아파트" },
    "resale-003" => ->(raw) { raw.dig("building_ledger", "floor_info")&.include?("반지하") },

    # 등기부등본 tab
    "rights-001" => ->(raw) { raw.dig("registry_transcript", "provisional_disposition_senior") == true },
    "rights-004" => ->(raw) { raw.dig("registry_transcript", "provisional_registration_type").present? },
    "rights-007" => ->(raw) { raw.dig("registry_transcript", "notice_registration") == true },
    "rights-008" => ->(raw) { raw.dig("registry_transcript", "senior_tax_seizure") == true },
    "rights-023" => ->(raw) {
      rights = raw.dig("registry_transcript", "rights") || []
      money_types = %w[근저당 가압류 압류]
      rights.all? { |r| money_types.include?(r["type"]) }
    },

    # 건축물대장 tab
    "property-004" => ->(raw) { raw.dig("building_ledger", "violation_flag") == true },
    "property-005" => ->(raw) { raw.dig("building_ledger", "usage_type") == "사무소" },
    "property-007" => ->(raw) { raw.dig("building_ledger", "has_elevator") == true },
    "resale-002" => ->(raw) { (raw.dig("building_ledger", "parking_per_unit") || 99) < 0.5 },
    "resale-004" => nil,
    "location-004" => ->(raw) { raw.dig("building_ledger", "room_structure").present? },
    "tax-006" => ->(raw) { raw.dig("building_ledger", "exclusive_area").present? },

    # 온라인조회 tab
    "property-001" => ->(raw) { raw.dig("court_auction", "is_partial_share") == true }
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

    InspectionItem.ordered.map do |item|
      result = @property.inspection_results.find_or_initialize_by(inspection_item: item, user: @user)

      rule = DETECTION_RULES[item.code]
      if rule.nil?
        result.assign_attributes(source_type: nil, has_risk: nil) unless result.persisted? && result.source_type.present?
      else
        detected = rule.call(raw)
        if detected.nil?
          result.assign_attributes(source_type: nil, has_risk: nil) unless result.persisted? && result.source_type.present?
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

- [ ] **Step 4: Run tests**

Run: `bin/rails test test/services/inspection_runner_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection_runner.rb test/services/inspection_runner_test.rb
git commit -m "feat: add InspectionRunner service with 89-item detection rules"
```

---

## Task 4: Create InspectionRatingService

**Files:**
- Create: `app/services/inspection_rating_service.rb`
- Create: `test/services/inspection_rating_service_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/services/inspection_rating_service_test.rb
require "test_helper"

class InspectionRatingServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
    @item = inspection_items(:rights_011)
    InspectionResult.where(property: @property, user: @user).destroy_all
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "rates safe when no risks" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :safe, rating
    assert_equal "safe", UserProperty.find_by(user: @user, property: @property).safety_rating
  end

  test "rates caution when risks are all resolvable" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: true)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :caution, rating
  end

  test "rates danger when any risk is unresolvable" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :danger, rating
  end

  test "returns incomplete when unanswered items exist" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :incomplete, rating
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/inspection_rating_service_test.rb`
Expected: FAIL — `NameError: uninitialized constant InspectionRatingService`

- [ ] **Step 3: Write the service**

```ruby
# app/services/inspection_rating_service.rb
class InspectionRatingService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    results = @property.inspection_results.where(user: @user)

    if results.exists?(has_risk: nil)
      return :incomplete
    end

    risk_results = results.where(has_risk: true)

    rating = if risk_results.exists?(resolvable: false)
      :danger
    elsif risk_results.any?
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

- [ ] **Step 4: Run tests**

Run: `bin/rails test test/services/inspection_rating_service_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection_rating_service.rb test/services/inspection_rating_service_test.rb
git commit -m "feat: add InspectionRatingService with incomplete state support"
```

---

## Task 5: Create PropertyInspectionService (Orchestrator)

**Files:**
- Create: `app/services/property_inspection_service.rb`
- Create: `test/services/property_inspection_service_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/services/property_inspection_service_test.rb
require "test_helper"

class PropertyInspectionServiceTest < ActiveSupport::TestCase
  setup do
    @property = PropertyDataSyncService.call(case_number: "2026타경10001")
    @user = users(:guest)
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "creates inspection results for all items" do
    PropertyInspectionService.call(property: @property, user: @user)
    assert_equal InspectionItem.count, InspectionResult.where(property: @property, user: @user).count
  end

  test "creates rights analysis report" do
    PropertyInspectionService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: @property, user: @user)
    assert_not_nil report
    assert_not_nil report.analyzed_at
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/property_inspection_service_test.rb`
Expected: FAIL — `NameError: uninitialized constant PropertyInspectionService`

- [ ] **Step 3: Write the service**

```ruby
# app/services/property_inspection_service.rb
class PropertyInspectionService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    InspectionRunner.call(property: @property, user: @user)
    RightsAnalysisService.call(property: @property, user: @user)
  end
end
```

- [ ] **Step 4: Run tests**

Run: `bin/rails test test/services/property_inspection_service_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/property_inspection_service.rb test/services/property_inspection_service_test.rb
git commit -m "feat: add PropertyInspectionService orchestrator"
```

---

## Task 6: Update RightsAnalysisService References

**Files:**
- Modify: `app/services/rights_analysis_service.rb`

The existing `RightsAnalysisService` references `property_check_results` and `checklist_item`. Update to use `inspection_results` and `inspection_item`.

- [ ] **Step 1: Update the service**

In `app/services/rights_analysis_service.rb`, change line 13:

```ruby
# Old:
check_results = @property.property_check_results.where(user: @user).includes(:checklist_item)
# New:
check_results = @property.inspection_results.where(user: @user).includes(:inspection_item)
```

In `find_checklist_references` method (around line 79), change:

```ruby
# Old:
check_results
  .select { |r| relevant_codes.include?(r.checklist_item.code) && r.has_risk == true }
  .map { |r| r.checklist_item.code }
# New:
check_results
  .select { |r| relevant_codes.include?(r.inspection_item.code) && r.has_risk == true }
  .map { |r| r.inspection_item.code }
```

In `compute_verdict` method (around line 85), change:

```ruby
# Old:
has_lien = check_results.any? { |r| r.checklist_item.code == "rights-011" && r.has_risk == true }
# New:
has_lien = check_results.any? { |r| r.inspection_item.code == "rights-011" && r.has_risk == true }
```

- [ ] **Step 2: Run existing rights analysis tests**

Run: `bin/rails test test/services/rights_analysis_service_test.rb`
Expected: All PASS (tests use PropertyDataSyncService which creates data — they should still work once seeds are updated)

- [ ] **Step 3: Commit**

```bash
git add app/services/rights_analysis_service.rb
git commit -m "refactor: update RightsAnalysisService to use InspectionResult/InspectionItem"
```

---

## Task 7: Update Seeds

**Files:**
- Modify: `db/seeds.rb`

- [ ] **Step 1: Replace the checklist seeding section**

Replace lines 56-81 in `db/seeds.rb` with:

```ruby
puts "Seeding inspection items..."

TAB_MAP = {
  "매각물건명세서" => "sale_document",
  "등기부등본" => "registry",
  "건축물대장" => "building_ledger",
  "온라인조회" => "online",
  "현장임장" => "field_visit",
  "기타" => "etc"
}.freeze

inspection_data = JSON.parse(File.read(Rails.root.join("db/seeds/checklist_items_summary.json")))
inspection_data.each do |attrs|
  code = attrs["id"]
  next unless code

  tab_key = TAB_MAP[attrs["tab"]]
  next unless tab_key

  InspectionItem.find_or_create_by!(code: code) do |item|
    item.tab = tab_key
    item.tab_position = attrs["tab_position"]
    item.category = attrs["category"]
    item.question = attrs["question"]
    item.description = attrs["description"]
    item.logic = attrs["logic"]
    item.data_source_name = attrs.dig("data_source", 0, "name") || "수동 입력"
    item.priority = attrs["priority"]
    item.merged_from = attrs["merged_from"]
  end
end
puts "  -> #{InspectionItem.count} inspection items (expected: 89)"
```

- [ ] **Step 2: Run seeds**

Run: `bin/rails db:seed`
Expected: Output shows `-> 89 inspection items (expected: 89)`

- [ ] **Step 3: Commit**

```bash
git add db/seeds.rb
git commit -m "refactor: update seeds to create InspectionItems from tab-based JSON"
```

---

## Task 8: Create Routes and Controllers

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/inspections/start_controller.rb`
- Create: `app/controllers/inspections/tabs_controller.rb`
- Create: `app/controllers/inspections/grades_controller.rb`
- Create: `app/controllers/inspections/dividends_controller.rb`
- Create: `test/controllers/inspections/start_controller_test.rb`
- Create: `test/controllers/inspections/tabs_controller_test.rb`
- Create: `test/controllers/inspections/grades_controller_test.rb`

- [ ] **Step 1: Update routes**

In `config/routes.rb`, replace the `analyses` block (lines 31-39) with:

```ruby
resources :properties, only: [ :index, :show, :create ] do
  namespace :inspections do
    resource :start, only: [ :create ], controller: "start"
    resources :tabs, only: [ :edit, :update ], param: :tab_key
    resource :grade, only: [ :show ], controller: "grades"
    resource :dividend, only: [ :update ], controller: "dividends"
  end
end
```

- [ ] **Step 2: Create StartController**

```ruby
# app/controllers/inspections/start_controller.rb
module Inspections
  class StartController < ApplicationController
    def create
      @property = Property.find(params[:property_id])
      PropertyInspectionService.call(property: @property, user: current_user)
      redirect_to edit_property_inspections_tab_url(@property, tab_key: "sale_document")
    end
  end
end
```

- [ ] **Step 3: Create TabsController**

```ruby
# app/controllers/inspections/tabs_controller.rb
module Inspections
  class TabsController < ApplicationController
    VALID_TABS = %w[sale_document registry building_ledger online field_visit etc].freeze

    def edit
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @tab_key = params[:tab_key]
      return head(:not_found) unless VALID_TABS.include?(@tab_key)

      @results = @property.inspection_results
        .where(user: current_user)
        .joins(:inspection_item)
        .where(inspection_items: { tab: InspectionItem.tabs[@tab_key] })
        .includes(:inspection_item)
        .order("inspection_items.tab_position")
    end

    def update
      @property = Property.find(params[:property_id])
      @tab_key = params[:tab_key]
      return head(:not_found) unless VALID_TABS.include?(@tab_key)

      if params[:resolutions].present?
        params[:resolutions].each do |id, values|
          result = @property.inspection_results.where(user: current_user).find(id)

          if result.auto?
            result.update!(
              resolvable: values[:resolvable] == "true",
              resolution_note: values[:resolution_note]
            )
          else
            has_risk = values[:has_risk] == "true"
            attrs = { source_type: "manual", has_risk: has_risk }

            if has_risk
              attrs[:resolvable] = values[:resolvable] == "true"
              attrs[:resolution_note] = values[:resolution_note]
            else
              attrs[:resolvable] = nil
              attrs[:resolution_note] = nil
            end

            result.update!(attrs)
          end
        end
      end

      redirect_to edit_property_inspections_tab_url(@property, tab_key: @tab_key)
    end
  end
end
```

- [ ] **Step 4: Create GradesController**

```ruby
# app/controllers/inspections/grades_controller.rb
module Inspections
  class GradesController < ApplicationController
    def show
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @rating = InspectionRatingService.call(property: @property, user: current_user)
      @report = RightsAnalysisReport.find_by(property: @property, user: current_user)

      @results_by_tab = @property.inspection_results
        .where(user: current_user)
        .includes(:inspection_item)
        .group_by { |r| r.inspection_item.tab }

      @risk_results = @property.inspection_results
        .where(has_risk: true, user: current_user)
        .includes(:inspection_item)
        .order("inspection_items.tab, inspection_items.tab_position")
    end
  end
end
```

- [ ] **Step 5: Create DividendsController**

```ruby
# app/controllers/inspections/dividends_controller.rb
module Inspections
  class DividendsController < ApplicationController
    def update
      @property = Property.find(params[:property_id])
      @report = RightsAnalysisReport.find_by!(property: @property, user: current_user)

      expected_bid = params[:expected_bid].present? ? params[:expected_bid].to_i : nil
      registry_data = @property.raw_data&.dig("registry_transcript")
      tenants = @report.report_data["tenants"]&.map(&:symbolize_keys) || []
      seizures = registry_data&.dig("seizures") || []
      rights = registry_data&.dig("rights") || []

      simulation = RightsAnalysis::DividendSimulator.call(
        rights: rights, tenants: tenants, seizures: seizures,
        expected_bid: expected_bid
      )

      report_data = @report.report_data.dup
      report_data["dividend_simulation"] = simulation.slice(:expected_bid, :distribution).deep_stringify_keys
      report_data["bidder_burden"] = simulation[:bidder_burden].deep_stringify_keys
      @report.update!(report_data: report_data)

      redirect_to property_inspections_grade_url(@property)
    end
  end
end
```

- [ ] **Step 6: Write controller tests**

```ruby
# test/controllers/inspections/start_controller_test.rb
require "test_helper"

class Inspections::StartControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: users(:guest), property: @property)
  end

  test "creates inspection results and redirects to first tab" do
    post property_inspections_start_url(@property)
    assert_redirected_to edit_property_inspections_tab_url(@property, tab_key: "sale_document")
    assert InspectionResult.where(property: @property, user: users(:guest)).exists?
  end
end
```

```ruby
# test/controllers/inspections/tabs_controller_test.rb
require "test_helper"

class Inspections::TabsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: users(:guest), property: @property)
    PropertyInspectionService.call(property: @property, user: users(:guest))
  end

  test "edit renders tab items" do
    get edit_property_inspections_tab_url(@property, tab_key: "sale_document")
    assert_response :success
  end

  test "edit returns 404 for invalid tab" do
    get edit_property_inspections_tab_url(@property, tab_key: "invalid")
    assert_response :not_found
  end

  test "update saves manual input" do
    result = @property.inspection_results.joins(:inspection_item)
      .where(inspection_items: { tab: InspectionItem.tabs["sale_document"] })
      .where(user: users(:guest))
      .where(source_type: nil)
      .first

    if result
      patch property_inspections_tab_url(@property, tab_key: "sale_document"), params: {
        resolutions: { result.id => { has_risk: "false" } }
      }
      assert_redirected_to edit_property_inspections_tab_url(@property, tab_key: "sale_document")
      result.reload
      assert_equal false, result.has_risk
    end
  end
end
```

```ruby
# test/controllers/inspections/grades_controller_test.rb
require "test_helper"

class Inspections::GradesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: users(:guest), property: @property)
    PropertyInspectionService.call(property: @property, user: users(:guest))
  end

  test "show renders grade page" do
    get property_inspections_grade_url(@property)
    assert_response :success
  end
end
```

- [ ] **Step 7: Run tests**

Run: `bin/rails test test/controllers/inspections/`
Expected: All PASS (views will be created in the next tasks — for now these tests may need view stubs)

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/inspections/ test/controllers/inspections/
git commit -m "feat: add inspections namespace with tab-based controllers"
```

---

## Task 9: Create UI Components

**Files:**
- Create: `app/components/inspection_tabs_component.rb` and `.html.erb`
- Create: `app/components/inspection_item_component.rb` and `.html.erb`
- Create: `app/components/inspection_group_component.rb` and `.html.erb`
- Create: `app/components/grade_summary_component.rb` and `.html.erb`
- Create: `app/components/tab_summary_table_component.rb` and `.html.erb`
- Create: `app/components/risk_items_list_component.rb` and `.html.erb`
- Create: `app/components/rights_report_section_component.rb` and `.html.erb`
- Create: Component tests

This is a large task. Each component follows the ViewComponent pattern from the existing codebase. Due to plan length constraints, implement each component one at a time following the existing patterns in the codebase (see `app/components/checklist_item_component.rb` for the card pattern, `app/components/stepper_component.rb` for the navigation pattern).

- [ ] **Step 1: Create InspectionTabsComponent**

This component replaces `StepperComponent`. It renders 7 horizontal tabs with completion badges.

```ruby
# app/components/inspection_tabs_component.rb
class InspectionTabsComponent < ViewComponent::Base
  TAB_CONFIG = [
    { key: "sale_document", label: "매각물건명세서" },
    { key: "registry",      label: "등기부등본" },
    { key: "building_ledger", label: "건축물대장" },
    { key: "online",        label: "온라인조회" },
    { key: "field_visit",   label: "현장임장" },
    { key: "etc",           label: "기타" },
    { key: "grade",         label: "최종등급" }
  ].freeze

  def initialize(property:, user:, active_tab:)
    @property = property
    @user = user
    @active_tab = active_tab
  end

  private

  def tabs
    TAB_CONFIG.map do |tab|
      counts = tab_counts(tab[:key])
      tab.merge(
        active: tab[:key] == @active_tab,
        url: tab_url(tab[:key]),
        checked: counts[:checked],
        total: counts[:total]
      )
    end
  end

  def tab_counts(key)
    return { checked: 0, total: 0 } if key == "grade"

    results = @property.inspection_results
      .joins(:inspection_item)
      .where(inspection_items: { tab: InspectionItem.tabs[key] }, user: @user)

    total = results.count
    checked = results.where.not(has_risk: nil).count
    { checked: checked, total: total }
  end

  def tab_url(key)
    if key == "grade"
      helpers.property_inspections_grade_path(@property)
    else
      helpers.edit_property_inspections_tab_path(@property, tab_key: key)
    end
  end
end
```

```erb
<%# app/components/inspection_tabs_component.html.erb %>
<nav class="mb-4 overflow-x-auto" data-controller="inspection-tabs">
  <div class="flex gap-1 text-sm min-w-max">
    <% tabs.each do |tab| %>
      <%= link_to tab[:url],
          class: "px-3 py-2 rounded-md transition-colors whitespace-nowrap #{tab[:active] ? 'bg-blue-600 text-white font-semibold' : 'bg-slate-800 text-slate-400 hover:bg-slate-700 hover:text-slate-200'}",
          data: { turbo_frame: "tab_content" } do %>
        <span><%= tab[:label] %></span>
        <% if tab[:total] > 0 %>
          <span class="ml-1 text-xs <%= tab[:active] ? 'text-blue-200' : 'text-slate-500' %>"><%= tab[:checked] %>/<%= tab[:total] %></span>
        <% end %>
      <% end %>
    <% end %>
  </div>
</nav>
```

- [ ] **Step 2: Create InspectionItemComponent**

Reuse the card pattern from old `ChecklistItemComponent` with the same risk/resolution logic.

```ruby
# app/components/inspection_item_component.rb
class InspectionItemComponent < ViewComponent::Base
  def initialize(result:, show_resolution: false)
    @result = result
    @item = result.inspection_item
    @show_resolution = show_resolution
  end

  private

  def auto_source? = @result.source_type == "auto"
  def manual_source? = !auto_source?

  def risk_classes
    if manual_source? && @result.has_risk.nil?
      "border-slate-300 bg-slate-50 dark:border-slate-600 dark:bg-slate-800/50"
    elsif @result.has_risk
      auto_source? ? "border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20" : "border-yellow-300 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20"
    else
      "border-green-300 bg-green-50 dark:border-green-600 dark:bg-green-900/20"
    end
  end

  def source_badge_text = auto_source? ? "AUTO" : "직접 확인"

  def status_text
    if manual_source? && @result.has_risk.nil? then "미입력"
    elsif @result.has_risk then auto_source? ? "위험" : "위험 확인"
    else "안전"
    end
  end

  def show_auto_resolution? = @show_resolution && auto_source? && @result.has_risk
  def show_manual_input? = @show_resolution && manual_source?
end
```

```erb
<%# app/components/inspection_item_component.html.erb %>
<div class="rounded-lg border p-4 <%= risk_classes %>"
     data-controller="inspection-item"
     data-inspection-item-result-id-value="<%= @result.id %>">
  <div class="flex items-start justify-between">
    <div class="flex items-center gap-2">
      <span class="inline-flex items-center rounded px-1.5 py-0.5 text-xs font-semibold bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"><%= source_badge_text %></span>
      <p class="text-sm font-medium text-slate-900 dark:text-slate-100"><%= @item.question %></p>
    </div>
    <span class="ml-2 shrink-0 text-xs font-semibold" data-inspection-item-target="statusLabel"><%= status_text %></span>
  </div>
  <% if @item.description.present? %>
    <p class="mt-1 text-xs text-slate-500 dark:text-slate-400"><%= @item.description %></p>
  <% end %>

  <% if show_auto_resolution? %>
    <div class="mt-3 border-t border-slate-200 dark:border-slate-600 pt-3">
      <div class="flex items-center gap-4">
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "true", @result.resolvable == true, class: "mr-1.5" %> 해결 가능
        </label>
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "false", @result.resolvable == false, class: "mr-1.5" %> 해결 불가
        </label>
      </div>
      <%= text_field_tag "resolutions[#{@result.id}][resolution_note]", @result.resolution_note,
          placeholder: "해결 방안 메모",
          class: "mt-2 w-full h-10 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 text-sm text-slate-900 dark:text-slate-200 placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors" %>
    </div>
  <% end %>

  <% if show_manual_input? %>
    <div class="mt-3 border-t border-slate-200 dark:border-slate-600 pt-3">
      <div class="flex items-center gap-4">
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", "true", @result.has_risk == true,
              data: { action: "change->inspection-item#toggleManualRisk" }, class: "mr-1.5" %> 예
        </label>
        <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
          <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", "false", @result.has_risk == false,
              data: { action: "change->inspection-item#toggleManualRisk" }, class: "mr-1.5" %> 아니오
        </label>
      </div>
      <div data-inspection-item-target="resolutionSection" class="<%= 'hidden' unless @result.has_risk %> mt-3 rounded-md border border-dashed border-yellow-400 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20 p-3">
        <p class="mb-2 text-xs font-medium text-yellow-800 dark:text-yellow-300">해결 가능 여부를 선택해주세요:</p>
        <div class="flex items-center gap-4">
          <label class="inline-flex items-center text-sm"><%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "true", @result.resolvable == true, class: "mr-1.5" %> 해결 가능</label>
          <label class="inline-flex items-center text-sm"><%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "false", @result.resolvable == false, class: "mr-1.5" %> 해결 불가</label>
        </div>
        <%= text_field_tag "resolutions[#{@result.id}][resolution_note]", @result.resolution_note,
            placeholder: "해결 방안 메모",
            class: "mt-2 w-full h-10 rounded-md border border-yellow-300 dark:border-yellow-600 bg-white dark:bg-slate-700 px-3 text-sm placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 transition-colors" %>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 3: Create InspectionGroupComponent**

```ruby
# app/components/inspection_group_component.rb
class InspectionGroupComponent < ViewComponent::Base
  def initialize(category:, results:)
    @category = category
    @results = results
  end

  private

  def risk_count = @results.count { |r| r.has_risk }
end
```

```erb
<%# app/components/inspection_group_component.html.erb %>
<div class="space-y-3">
  <div class="flex items-center justify-between">
    <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100"><%= @category %></h3>
    <% if risk_count > 0 %>
      <span class="text-xs font-medium text-red-600 dark:text-red-400"><%= risk_count %>건 위험</span>
    <% end %>
  </div>
  <div class="space-y-2">
    <% @results.each do |result| %>
      <%= render InspectionItemComponent.new(result: result, show_resolution: true) %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Create GradeSummaryComponent**

```ruby
# app/components/grade_summary_component.rb
class GradeSummaryComponent < ViewComponent::Base
  RATING_CONFIG = {
    safe: { color: "text-green-700 dark:text-green-400", bg: "bg-green-50 dark:bg-green-900/20 border-green-300 dark:border-green-700", label: "안전", description: "위험 항목이 없습니다" },
    caution: { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-50 dark:bg-yellow-900/20 border-yellow-300 dark:border-yellow-700", label: "주의", description: "위험 항목이 있으나 모두 해결 가능합니다" },
    danger: { color: "text-red-700 dark:text-red-400", bg: "bg-red-50 dark:bg-red-900/20 border-red-300 dark:border-red-700", label: "경고", description: "해결 불가능한 위험 항목이 있습니다" },
    incomplete: { color: "text-slate-500 dark:text-slate-400", bg: "bg-slate-50 dark:bg-slate-800/50 border-slate-300 dark:border-slate-600", label: "미완료", description: "아직 확인하지 않은 항목이 있습니다" }
  }.freeze

  def initialize(rating:)
    @config = RATING_CONFIG[rating] || RATING_CONFIG[:incomplete]
  end
end
```

```erb
<%# app/components/grade_summary_component.html.erb %>
<div class="rounded-xl border-2 p-8 text-center <%= @config[:bg] %>">
  <div class="text-4xl font-bold <%= @config[:color] %>"><%= @config[:label] %></div>
  <p class="mt-2 text-sm text-slate-600 dark:text-slate-400"><%= @config[:description] %></p>
</div>
```

- [ ] **Step 5: Create TabSummaryTableComponent**

```ruby
# app/components/tab_summary_table_component.rb
class TabSummaryTableComponent < ViewComponent::Base
  TAB_LABELS = {
    "sale_document" => "매각물건명세서",
    "registry" => "등기부등본",
    "building_ledger" => "건축물대장",
    "online" => "온라인조회",
    "field_visit" => "현장임장",
    "etc" => "기타"
  }.freeze

  def initialize(results_by_tab:, property:)
    @results_by_tab = results_by_tab
    @property = property
  end

  private

  def rows
    TAB_LABELS.map do |key, label|
      results = @results_by_tab[key] || []
      safe = results.count { |r| r.has_risk == false }
      risk = results.count { |r| r.has_risk == true }
      unanswered = results.count { |r| r.has_risk.nil? }
      { key: key, label: label, safe: safe, risk: risk, unanswered: unanswered }
    end
  end
end
```

```erb
<%# app/components/tab_summary_table_component.html.erb %>
<div class="overflow-hidden rounded-lg border border-slate-200 dark:border-slate-700">
  <table class="min-w-full text-sm">
    <thead class="bg-slate-50 dark:bg-slate-800">
      <tr>
        <th class="px-4 py-2 text-left font-medium text-slate-600 dark:text-slate-300">탭</th>
        <th class="px-4 py-2 text-center font-medium text-green-600">안전</th>
        <th class="px-4 py-2 text-center font-medium text-red-600">위험</th>
        <th class="px-4 py-2 text-center font-medium text-slate-500">미입력</th>
      </tr>
    </thead>
    <tbody class="divide-y divide-slate-200 dark:divide-slate-700">
      <% rows.each do |row| %>
        <tr>
          <td class="px-4 py-2">
            <%= link_to row[:label], helpers.edit_property_inspections_tab_path(@property, tab_key: row[:key]),
                class: "text-blue-600 dark:text-blue-400 hover:underline", data: { turbo_frame: "tab_content" } %>
          </td>
          <td class="px-4 py-2 text-center text-green-600"><%= row[:safe] %></td>
          <td class="px-4 py-2 text-center text-red-600"><%= row[:risk] %></td>
          <td class="px-4 py-2 text-center text-slate-500"><%= row[:unanswered] %></td>
        </tr>
      <% end %>
    </tbody>
  </table>
</div>
```

- [ ] **Step 6: Create RiskItemsListComponent**

```ruby
# app/components/risk_items_list_component.rb
class RiskItemsListComponent < ViewComponent::Base
  def initialize(risk_results:)
    @unresolvable = risk_results.select { |r| r.resolvable == false }
    @resolvable = risk_results.select { |r| r.resolvable == true }
  end
end
```

```erb
<%# app/components/risk_items_list_component.html.erb %>
<div class="space-y-4">
  <% if @unresolvable.any? %>
    <div>
      <h4 class="text-sm font-semibold text-red-700 dark:text-red-400 mb-2">해결 불가능 (<%= @unresolvable.size %>건)</h4>
      <div class="space-y-2">
        <% @unresolvable.each do |result| %>
          <div class="rounded-md border border-red-300 dark:border-red-700 bg-red-50 dark:bg-red-900/20 p-3">
            <p class="text-sm font-medium text-slate-900 dark:text-slate-100"><%= result.inspection_item.question %></p>
            <p class="text-xs text-slate-500 mt-1"><%= result.inspection_item.data_source_name %></p>
          </div>
        <% end %>
      </div>
    </div>
  <% end %>
  <% if @resolvable.any? %>
    <div>
      <h4 class="text-sm font-semibold text-yellow-700 dark:text-yellow-400 mb-2">해결 가능 (<%= @resolvable.size %>건)</h4>
      <div class="space-y-2">
        <% @resolvable.each do |result| %>
          <div class="rounded-md border border-yellow-300 dark:border-yellow-700 bg-yellow-50 dark:bg-yellow-900/20 p-3">
            <p class="text-sm font-medium text-slate-900 dark:text-slate-100"><%= result.inspection_item.question %></p>
            <% if result.resolution_note.present? %>
              <p class="text-xs text-slate-600 dark:text-slate-400 mt-1"><%= result.resolution_note %></p>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 7: Create RightsReportSectionComponent**

```ruby
# app/components/rights_report_section_component.rb
class RightsReportSectionComponent < ViewComponent::Base
  def initialize(report:, property:)
    @report = report
    @property = property
  end
end
```

```erb
<%# app/components/rights_report_section_component.html.erb %>
<% if @report %>
  <div class="space-y-4">
    <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">권리 분석 리포트</h3>

    <%= render ReportSummaryComponent.new(report: @report) %>
    <%= render RegistryTimelineComponent.new(report: @report) %>
    <%= render DividendSimulatorComponent.new(report: @report, property: @property) %>
    <%= render SourceDocViewerComponent.new(property: @property) %>
    <%= render LegalDisclaimerComponent.new %>
  </div>
<% end %>
```

- [ ] **Step 8: Write component tests**

Write tests for each component following the pattern in existing tests (e.g., `test/components/checklist_item_component_test.rb`). Each test verifies correct rendering for each state (safe, risk, unanswered, etc.).

- [ ] **Step 9: Commit**

```bash
git add app/components/inspection_* app/components/grade_summary_* app/components/tab_summary_* app/components/risk_items_* app/components/rights_report_section_* test/components/
git commit -m "feat: add inspection UI components (tabs, items, grade, summary)"
```

---

## Task 10: Create Views and Stimulus Controllers

**Files:**
- Create: `app/views/inspections/_layout.html.erb`
- Create: `app/views/inspections/tabs/edit.html.erb`
- Create: `app/views/inspections/grades/show.html.erb`
- Create: `app/javascript/controllers/inspection_tabs_controller.js`
- Create: `app/javascript/controllers/inspection_item_controller.js`

- [ ] **Step 1: Create layout partial**

```erb
<%# app/views/inspections/_layout.html.erb %>
<div class="space-y-3">
  <%= link_to "← 목록", properties_path, class: "text-sm text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-300" %>
  <%= render "analyses/property_card_compact", property: property, user_property: user_property %>
  <%= render InspectionTabsComponent.new(property: property, user: current_user, active_tab: active_tab) %>
  <%= turbo_frame_tag "tab_content" do %>
    <%= yield %>
  <% end %>
</div>
```

- [ ] **Step 2: Create tab edit view**

```erb
<%# app/views/inspections/tabs/edit.html.erb %>
<%= render layout: "inspections/layout", locals: { property: @property, user_property: @user_property, active_tab: @tab_key } do %>
  <%= form_with url: property_inspections_tab_path(@property, tab_key: @tab_key), method: :patch, data: { turbo: false } do |f| %>
    <div class="space-y-6">
      <% @results.group_by { |r| r.inspection_item.category }.each do |category, results| %>
        <%= render InspectionGroupComponent.new(category: category, results: results) %>
      <% end %>
    </div>
    <div class="mt-6">
      <%= f.submit "저장", class: "w-full rounded-lg bg-blue-600 px-4 py-3 text-sm font-semibold text-white hover:bg-blue-700 transition-colors" %>
    </div>
  <% end %>
<% end %>
```

- [ ] **Step 3: Create grade show view**

```erb
<%# app/views/inspections/grades/show.html.erb %>
<%= render layout: "inspections/layout", locals: { property: @property, user_property: @user_property, active_tab: "grade" } do %>
  <div class="space-y-6">
    <%= render GradeSummaryComponent.new(rating: @rating) %>
    <%= render TabSummaryTableComponent.new(results_by_tab: @results_by_tab, property: @property) %>

    <% if @risk_results.any? %>
      <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">위험 항목 상세</h3>
      <%= render RiskItemsListComponent.new(risk_results: @risk_results) %>
    <% end %>

    <%= render RightsReportSectionComponent.new(report: @report, property: @property) %>

    <div class="flex gap-3">
      <%= link_to "목록으로 돌아가기", properties_path, class: "flex-1 rounded-lg border border-slate-300 dark:border-slate-600 px-4 py-3 text-sm font-semibold text-center text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700 transition-colors" %>
    </div>
  </div>
<% end %>
```

- [ ] **Step 4: Create Stimulus controllers**

```javascript
// app/javascript/controllers/inspection_tabs_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Tab switching handled by Turbo Frames — no custom logic needed
  // This controller exists as a namespace for future tab behavior
}
```

```javascript
// app/javascript/controllers/inspection_item_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["resolutionSection", "statusLabel"]
  static values = { resultId: Number }

  toggleManualRisk(event) {
    const hasRisk = event.target.value === "true"

    if (hasRisk) {
      this.resolutionSectionTarget.classList.remove("hidden")
    } else {
      this.resolutionSectionTarget.classList.add("hidden")
      this.resolutionSectionTarget.querySelectorAll("input[type='radio']").forEach(r => r.checked = false)
      this.resolutionSectionTarget.querySelectorAll("input[type='text']").forEach(t => t.value = "")
    }
  }
}
```

- [ ] **Step 5: Commit**

```bash
git add app/views/inspections/ app/javascript/controllers/inspection_tabs_controller.js app/javascript/controllers/inspection_item_controller.js
git commit -m "feat: add inspection views and Stimulus controllers"
```

---

## Task 11: Delete Old Code

**Files:**
- Delete old models, services, controllers, views, components, tests, fixtures

- [ ] **Step 1: Delete old files**

```bash
# Models
rm app/models/checklist_item.rb
rm app/models/property_check_result.rb

# Services
rm app/services/auto_check_runner.rb
rm app/services/safety_rating_service.rb
rm app/services/property_analysis_service.rb

# Controllers
rm -rf app/controllers/analyses/

# Views
rm -rf app/views/analyses/

# Components
rm app/components/stepper_component.rb app/components/stepper_component.html.erb
rm app/components/checklist_group_component.rb app/components/checklist_group_component.html.erb
rm app/components/checklist_item_component.rb app/components/checklist_item_component.html.erb

# Stimulus
rm app/javascript/controllers/stepper_controller.js
rm app/javascript/controllers/resolution_input_controller.js

# Tests
rm test/models/checklist_item_test.rb
rm test/models/property_check_result_test.rb
rm test/services/auto_check_runner_test.rb
rm test/services/safety_rating_service_test.rb
rm test/services/property_analysis_service_test.rb
rm -rf test/controllers/analyses/
rm test/components/stepper_component_test.rb
rm test/components/checklist_group_component_test.rb
rm test/components/checklist_item_component_test.rb
rm test/integration/property_analysis_flow_test.rb

# Fixtures
rm test/fixtures/checklist_items.yml
rm test/fixtures/property_check_results.yml
```

- [ ] **Step 2: Remove old associations from Property model**

Verify `app/models/property.rb` no longer references `property_check_results` or `checklist_items` (already updated in Task 2).

- [ ] **Step 3: Run full test suite**

Run: `bin/rails test`
Expected: Fix any remaining references to deleted code. Integration tests referencing old routes/controllers need to be removed or rewritten.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "chore: remove old checklist/stepper code (replaced by inspection system)"
```

---

## Task 12: Drop Old Tables

**Files:**
- Create: `db/migrate/TIMESTAMP_drop_checklist_items.rb`
- Create: `db/migrate/TIMESTAMP_drop_property_check_results.rb`

- [ ] **Step 1: Generate migrations**

Run: `bin/rails generate migration DropPropertyCheckResults`

```ruby
class DropPropertyCheckResults < ActiveRecord::Migration[8.1]
  def change
    drop_table :property_check_results
  end
end
```

Run: `bin/rails generate migration DropChecklistItems`

```ruby
class DropChecklistItems < ActiveRecord::Migration[8.1]
  def change
    drop_table :checklist_items
  end
end
```

- [ ] **Step 2: Run migrations**

Run: `bin/rails db:migrate`

- [ ] **Step 3: Run full test suite**

Run: `bin/rails test`
Expected: All PASS

- [ ] **Step 4: Verify seeds work from scratch**

Run: `bin/rails db:reset`
Expected: Seeds complete with 89 inspection items

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*drop_* db/schema.rb
git commit -m "chore: drop legacy checklist_items and property_check_results tables"
```

---

## Task 13: Integration Test

**Files:**
- Create: `test/integration/property_inspection_flow_test.rb`

- [ ] **Step 1: Write integration test**

```ruby
# test/integration/property_inspection_flow_test.rb
require "test_helper"

class PropertyInspectionFlowTest < ActionDispatch::IntegrationTest
  setup do
    @property = PropertyDataSyncService.call(case_number: "2026타경10001")
    @user = users(:guest)
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "full inspection flow: start → tab edit → grade" do
    # Start inspection
    post property_inspections_start_url(@property)
    assert_redirected_to edit_property_inspections_tab_url(@property, tab_key: "sale_document")

    # Verify items created
    assert_equal InspectionItem.count, InspectionResult.where(property: @property, user: @user).count

    # Visit each tab
    %w[sale_document registry building_ledger online field_visit etc].each do |tab|
      get edit_property_inspections_tab_url(@property, tab_key: tab)
      assert_response :success
    end

    # View grade
    get property_inspections_grade_url(@property)
    assert_response :success
  end

  test "manual input updates result" do
    PropertyInspectionService.call(property: @property, user: @user)

    manual_result = @property.inspection_results
      .joins(:inspection_item)
      .where(user: @user, source_type: nil)
      .first

    if manual_result
      patch property_inspections_tab_url(@property, tab_key: manual_result.inspection_item.tab), params: {
        resolutions: { manual_result.id => { has_risk: "true", resolvable: "true", resolution_note: "확인 완료" } }
      }
      manual_result.reload
      assert_equal true, manual_result.has_risk
      assert_equal true, manual_result.resolvable
      assert_equal "확인 완료", manual_result.resolution_note
    end
  end
end
```

- [ ] **Step 2: Run integration tests**

Run: `bin/rails test test/integration/property_inspection_flow_test.rb`
Expected: All PASS

- [ ] **Step 3: Run full test suite and CI**

Run: `bin/ci`
Expected: All checks pass (rubocop, brakeman, tests, seeds)

- [ ] **Step 4: Commit**

```bash
git add test/integration/property_inspection_flow_test.rb
git commit -m "test: add full property inspection flow integration test"
```
