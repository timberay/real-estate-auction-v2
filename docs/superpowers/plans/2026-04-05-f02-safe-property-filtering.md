# F02 Safe Property Auto-Filtering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement checklist-driven safety analysis that auto-detects risky auction properties across 3 axes (legal, resale, loan) and rates them Safe/Caution/Danger based on user-resolvability.

**Architecture:** Checklist engine pattern — 17 master ChecklistItems seeded from JSON, per-property results stored in PropertyCheckResult junction table. Adapters fetch data from 매각물건명세서 + 건축물대장 APIs (mock for MVP). Interactive 4-step analysis flow via Turbo Frames.

**Tech Stack:** Rails 8.1, SQLite, Hotwire (Turbo Frames + Stimulus), ViewComponent, TailwindCSS, Minitest

**Spec:** `docs/superpowers/specs/2026-04-05-f02-safe-property-filtering-design.md`

---

## File Structure

### Models
- `app/models/property.rb` — auction property keyed by case_number, stores raw API data
- `app/models/checklist_item.rb` — master risk check items (17), seeded from JSON
- `app/models/property_check_result.rb` — per-property per-item results, junction table

### Adapters
- `app/adapters/court_auction_adapter.rb` — base + factory for 매각물건명세서
- `app/adapters/mock_court_auction_adapter.rb` — mock data for development
- `app/adapters/government_court_auction_adapter.rb` — real API (stub for MVP)
- `app/adapters/building_ledger_adapter.rb` — base + factory for 건축물대장
- `app/adapters/mock_building_ledger_adapter.rb` — mock data for development
- `app/adapters/government_building_ledger_adapter.rb` — real API (stub for MVP)

### Services
- `app/services/property_data_sync_service.rb` — fetches + upserts property data via adapters
- `app/services/property_analysis_service.rb` — orchestrates full analysis flow
- `app/services/auto_check_runner.rb` — runs 17 detection rules against raw_data
- `app/services/safety_rating_service.rb` — calculates Safe/Caution/Danger from results

### Controllers
- `app/controllers/properties_controller.rb` — index (list + filter), show (detail)
- `app/controllers/analyses/start_controller.rb` — POST triggers analysis
- `app/controllers/analyses/manual_inputs_controller.rb` — edit/update manual answers
- `app/controllers/analyses/results_controller.rb` — edit/update resolution inputs
- `app/controllers/analyses/ratings_controller.rb` — show final rating

### ViewComponents
- `app/components/safety_badge_component.rb` — Safe/Caution/Danger/Unanalyzed badge
- `app/components/property_card_component.rb` — property list card
- `app/components/checklist_item_component.rb` — single check item display
- `app/components/checklist_group_component.rb` — risk axis group wrapper
- `app/components/rating_result_component.rb` — large rating card with justification

### Stimulus Controllers
- `app/javascript/controllers/manual_input_controller.js` — validates all items answered
- `app/javascript/controllers/resolution_input_controller.js` — toggles note fields
- `app/javascript/controllers/property_filter_controller.js` — "Safe만 보기" preset

### Seeds
- `db/seeds/checklist_items_summary.json` — moved from `docs/`, 5 items added
- `db/seeds/mock_properties.json` — diverse mock property data

---

## Phase 1: Database Foundation

### Task 1: Create Property Model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_properties.rb`
- Create: `app/models/property.rb`
- Create: `test/models/property_test.rb`
- Create: `test/fixtures/properties.yml`

- [ ] **Step 1: Write failing test**

```ruby
# test/models/property_test.rb
require "test_helper"

class PropertyTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    property = Property.new(
      case_number: "2026타경12345",
      court_name: "서울중앙지방법원",
      address: "서울특별시 강남구 역삼동 123-45",
      appraisal_price: 50000,
      min_bid_price: 35000
    )
    assert property.valid?
  end

  test "case_number is required" do
    property = Property.new(case_number: nil)
    assert_not property.valid?
    assert_includes property.errors[:case_number], "can't be blank"
  end

  test "case_number must be unique" do
    Property.create!(case_number: "2026타경12345", court_name: "서울중앙", address: "서울시", appraisal_price: 50000, min_bid_price: 35000)
    duplicate = Property.new(case_number: "2026타경12345")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:case_number], "has already been taken"
  end

  test "safety_rating enum values" do
    property = properties(:safe_apartment)
    property.safety_rating = "safe"
    assert_equal "safe", property.safety_rating
    assert property.safe?

    property.safety_rating = "caution"
    assert property.caution?

    property.safety_rating = "danger"
    assert property.danger?
  end

  test "safety_rating defaults to nil (unanalyzed)" do
    property = Property.new(case_number: "2026타경99999", court_name: "서울중앙", address: "서울시", appraisal_price: 50000, min_bid_price: 35000)
    assert_nil property.safety_rating
  end
end
```

- [ ] **Step 2: Create fixtures**

```yaml
# test/fixtures/properties.yml
safe_apartment:
  case_number: "2026타경10001"
  court_name: "서울중앙지방법원"
  property_type: "아파트"
  address: "서울특별시 강남구 역삼동 100-1"
  appraisal_price: 80000
  min_bid_price: 56000
  status: "진행중"
  safety_rating: "safe"

risky_villa:
  case_number: "2026타경10002"
  court_name: "수원지방법원"
  property_type: "빌라"
  address: "경기도 수원시 영통구 200-2"
  appraisal_price: 30000
  min_bid_price: 21000
  status: "진행중"
  safety_rating: "danger"

unanalyzed_officetel:
  case_number: "2026타경10003"
  court_name: "인천지방법원"
  property_type: "오피스텔"
  address: "인천광역시 연수구 300-3"
  appraisal_price: 25000
  min_bid_price: 17500
  status: "진행중"
```

- [ ] **Step 3: Generate migration and implement model**

```ruby
# db/migrate/TIMESTAMP_create_properties.rb
class CreateProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :properties do |t|
      t.string :case_number, null: false
      t.string :court_name
      t.string :property_type
      t.string :address
      t.integer :appraisal_price
      t.integer :min_bid_price
      t.string :status
      t.integer :safety_rating
      t.json :raw_data
      t.references :user, foreign_key: true
      t.timestamps
    end
    add_index :properties, :case_number, unique: true
    add_index :properties, :safety_rating
  end
end
```

```ruby
# app/models/property.rb
class Property < ApplicationRecord
  belongs_to :user, optional: true

  enum :safety_rating, { safe: 0, caution: 1, danger: 2 }, prefix: true

  validates :case_number, presence: true, uniqueness: true
end
```

- [ ] **Step 4: Run tests, verify green**

Run: `bin/rails db:migrate && bin/rails test test/models/property_test.rb`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add app/models/property.rb db/migrate/*_create_properties.rb test/models/property_test.rb test/fixtures/properties.yml
git commit -m "feat(f02): add Property model with case_number upsert and safety_rating enum"
```

---

### Task 2: Create ChecklistItem Model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_checklist_items.rb`
- Create: `app/models/checklist_item.rb`
- Create: `test/models/checklist_item_test.rb`
- Create: `test/fixtures/checklist_items.yml`

- [ ] **Step 1: Write failing test**

```ruby
# test/models/checklist_item_test.rb
require "test_helper"

class ChecklistItemTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    item = ChecklistItem.new(
      code: "test-001",
      category: "권리분석",
      risk_axis: "legal",
      question: "테스트 질문입니까?",
      description: "테스트 설명",
      data_source_name: "매각물건명세서",
      priority: "상",
      position: 1
    )
    assert item.valid?
  end

  test "code is required and unique" do
    item = ChecklistItem.new(code: nil)
    assert_not item.valid?
    assert_includes item.errors[:code], "can't be blank"
  end

  test "code uniqueness" do
    ChecklistItem.create!(code: "test-unique", category: "권리분석", risk_axis: "legal", question: "Q?", description: "D", data_source_name: "매각물건명세서", priority: "상", position: 99)
    dup = ChecklistItem.new(code: "test-unique", risk_axis: "legal", question: "Q2?")
    assert_not dup.valid?
  end

  test "risk_axis enum" do
    item = checklist_items(:rights_011)
    assert item.legal?
    item.risk_axis = "resale"
    assert item.resale?
    item.risk_axis = "loan"
    assert item.loan?
  end

  test "question is required" do
    item = ChecklistItem.new(code: "test-002", risk_axis: "legal", question: nil)
    assert_not item.valid?
    assert_includes item.errors[:question], "can't be blank"
  end

  test "scope by_risk_axis" do
    legal_items = ChecklistItem.legal
    assert legal_items.all? { |i| i.legal? }
  end

  test "ordered scope returns items by position" do
    items = ChecklistItem.ordered
    positions = items.map(&:position)
    assert_equal positions, positions.sort
  end
end
```

- [ ] **Step 2: Create fixtures**

```yaml
# test/fixtures/checklist_items.yml
rights_011:
  code: "rights-011"
  category: "권리분석"
  risk_axis: 0
  question: "매각물건명세서 비고란에 유치권 또는 법정지상권이 적혀 있습니까?"
  description: "유치권은 공사대금 미지급 등으로 점유를 주장하는 것이고, 법정지상권은 토지와 건물 소유자가 달라질 때 발생합니다."
  logic: '{"yes": "인수해야 할 중대 권리가 명시되어 있습니다.", "no": "치명적인 특수 권리가 없습니다."}'
  data_source_name: "매각물건명세서"
  priority: "상"
  position: 1

rights_002:
  code: "rights-002"
  category: "권리분석"
  risk_axis: 0
  question: "매각물건명세서의 '소멸되지 아니하는 것' 비고란에 기재된 인수 권리가 있습니까?"
  description: "법원이 직접 '이 권리는 낙찰자가 떠안는다'고 명시한 것입니다."
  logic: '{"yes": "법원이 인수 권리를 명시했으므로 초보자는 입찰을 피해야 합니다.", "no": "안전합니다."}'
  data_source_name: "매각물건명세서"
  priority: "상"
  position: 2

property_004:
  code: "property-004"
  category: "물건 기본 필터링"
  risk_axis: 2
  question: "건축물대장에 노란색으로 '위반건축물'이라고 표시되어 있습니까?"
  description: "위반건축물은 이행강제금 부과, 대출 제한, 용도변경 불가 등 심각한 불이익이 있습니다."
  logic: '{"yes": "대출이 안 나오고 이행강제금이 발생합니다.", "no": "위반 사항이 없습니다."}'
  data_source_name: "건축물대장"
  priority: "상"
  position: 15
```

- [ ] **Step 3: Generate migration and implement model**

```ruby
# db/migrate/TIMESTAMP_create_checklist_items.rb
class CreateChecklistItems < ActiveRecord::Migration[8.1]
  def change
    create_table :checklist_items do |t|
      t.string :code, null: false
      t.string :category, null: false
      t.integer :risk_axis, null: false
      t.text :question, null: false
      t.text :description
      t.json :logic
      t.string :data_source_name
      t.string :priority, null: false, default: "상"
      t.integer :position, null: false, default: 0
      t.timestamps
    end
    add_index :checklist_items, :code, unique: true
    add_index :checklist_items, :risk_axis
    add_index :checklist_items, :position
  end
end
```

```ruby
# app/models/checklist_item.rb
class ChecklistItem < ApplicationRecord
  enum :risk_axis, { legal: 0, resale: 1, loan: 2 }, prefix: true

  validates :code, presence: true, uniqueness: true
  validates :question, presence: true
  validates :category, presence: true
  validates :risk_axis, presence: true

  scope :ordered, -> { order(:position) }
end
```

- [ ] **Step 4: Run tests, verify green**

Run: `bin/rails db:migrate && bin/rails test test/models/checklist_item_test.rb`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add app/models/checklist_item.rb db/migrate/*_create_checklist_items.rb test/models/checklist_item_test.rb test/fixtures/checklist_items.yml
git commit -m "feat(f02): add ChecklistItem model with risk_axis enum and seed support"
```

---

### Task 3: Create PropertyCheckResult Model

**Files:**
- Create: `db/migrate/TIMESTAMP_create_property_check_results.rb`
- Create: `app/models/property_check_result.rb`
- Create: `test/models/property_check_result_test.rb`
- Create: `test/fixtures/property_check_results.yml`

- [ ] **Step 1: Write failing test**

```ruby
# test/models/property_check_result_test.rb
require "test_helper"

class PropertyCheckResultTest < ActiveSupport::TestCase
  test "valid with property and checklist_item" do
    result = PropertyCheckResult.new(
      property: properties(:safe_apartment),
      checklist_item: checklist_items(:rights_011),
      source_type: "auto",
      has_risk: false
    )
    assert result.valid?
  end

  test "property and checklist_item combination must be unique" do
    PropertyCheckResult.create!(
      property: properties(:safe_apartment),
      checklist_item: checklist_items(:rights_011),
      source_type: "auto",
      has_risk: false
    )
    dup = PropertyCheckResult.new(
      property: properties(:safe_apartment),
      checklist_item: checklist_items(:rights_011)
    )
    assert_not dup.valid?
  end

  test "source_type enum" do
    result = PropertyCheckResult.new(source_type: "auto")
    assert result.auto?
    result.source_type = "manual"
    assert result.manual?
  end

  test "resolvable is nil by default" do
    result = PropertyCheckResult.new(
      property: properties(:safe_apartment),
      checklist_item: checklist_items(:rights_011),
      source_type: "auto",
      has_risk: true
    )
    assert_nil result.resolvable
  end
end
```

- [ ] **Step 2: Create fixtures**

```yaml
# test/fixtures/property_check_results.yml
safe_apartment_rights_011:
  property: safe_apartment
  checklist_item: rights_011
  source_type: 0
  has_risk: false

risky_villa_rights_011:
  property: risky_villa
  checklist_item: rights_011
  source_type: 0
  has_risk: true
  resolvable: false
```

- [ ] **Step 3: Generate migration and implement model**

```ruby
# db/migrate/TIMESTAMP_create_property_check_results.rb
class CreatePropertyCheckResults < ActiveRecord::Migration[8.1]
  def change
    create_table :property_check_results do |t|
      t.references :property, null: false, foreign_key: true
      t.references :checklist_item, null: false, foreign_key: true
      t.integer :source_type
      t.text :api_value
      t.text :manual_value
      t.boolean :has_risk
      t.boolean :resolvable
      t.text :resolution_note
      t.timestamps
    end
    add_index :property_check_results, [ :property_id, :checklist_item_id ], unique: true, name: "idx_check_results_property_item"
  end
end
```

```ruby
# app/models/property_check_result.rb
class PropertyCheckResult < ApplicationRecord
  belongs_to :property
  belongs_to :checklist_item

  enum :source_type, { auto: 0, manual: 1 }, prefix: true

  validates :property_id, uniqueness: { scope: :checklist_item_id }
end
```

- [ ] **Step 4: Run tests, verify green**

Run: `bin/rails db:migrate && bin/rails test test/models/property_check_result_test.rb`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add app/models/property_check_result.rb db/migrate/*_create_property_check_results.rb test/models/property_check_result_test.rb test/fixtures/property_check_results.yml
git commit -m "feat(f02): add PropertyCheckResult junction model with source_type enum"
```

---

### Task 4: Add Model Associations

**Files:**
- Modify: `app/models/property.rb`
- Modify: `app/models/checklist_item.rb`

- [ ] **Step 1: Add has_many associations**

```ruby
# app/models/property.rb — add after belongs_to :user
has_many :property_check_results, dependent: :destroy
has_many :checklist_items, through: :property_check_results
```

```ruby
# app/models/checklist_item.rb — add before validations
has_many :property_check_results, dependent: :destroy
```

- [ ] **Step 2: Write association tests**

```ruby
# Add to test/models/property_test.rb
test "has_many property_check_results" do
  property = properties(:safe_apartment)
  assert_respond_to property, :property_check_results
end

# Add to test/models/checklist_item_test.rb
test "has_many property_check_results" do
  item = checklist_items(:rights_011)
  assert_respond_to item, :property_check_results
end
```

- [ ] **Step 3: Run tests, commit**

Run: `bin/rails test test/models/`
Expected: All pass

```bash
git add app/models/property.rb app/models/checklist_item.rb test/models/
git commit -m "feat(f02): add has_many associations between Property, ChecklistItem, and PropertyCheckResult"
```

---

### Task 5: Move Checklist JSON and Seed ChecklistItems

**Files:**
- Move: `docs/checklist_items_summary.json` → `db/seeds/checklist_items_summary.json`
- Modify: `db/seeds.rb`

- [ ] **Step 1: Move file and add missing items**

```bash
mv docs/checklist_items_summary.json db/seeds/checklist_items_summary.json
```

Add 5 missing items to the JSON array (append before the closing `]`):

```json
{
  "category": "권리분석",
  "question": "분묘기지권(묘지 사용 권리)이 존재합니까?",
  "description": "분묘기지권은 타인의 토지에 설치된 분묘를 소유하기 위해 토지를 사용할 수 있는 권리로, 토지 이용에 심각한 제약이 됩니다.",
  "logic": {"yes": "토지 활용이 극도로 제한됩니다.", "no": "분묘기지권 리스크가 없습니다."},
  "data_source": [{"name": "수동 입력", "url": null}],
  "priority": "상",
  "f02_code": "manual-001",
  "f02_risk_axis": "legal"
},
{
  "category": "물건 기본 필터링",
  "question": "빌라의 방 구조가 원룸 또는 1.5룸입니까?",
  "description": "원룸과 1.5룸 빌라는 재판매가 어렵고 대출 제한이 있어 투자 리스크가 높습니다.",
  "logic": {"yes": "재판매 + 대출 제한이 있어 위험합니다.", "no": "방 구조상 문제가 없습니다."},
  "data_source": [{"name": "건축물대장", "url": "https://www.gov.kr"}],
  "priority": "상",
  "f02_code": "resale-001",
  "f02_risk_axis": "resale"
},
{
  "category": "물건 기본 필터링",
  "question": "빌라의 세대수 대비 주차 공간이 부족합니까?",
  "description": "주차 공간 부족은 거주 만족도를 낮추고 매매가에 부정적 영향을 미칩니다.",
  "logic": {"yes": "주차 부족으로 매도 시 불리합니다.", "no": "주차 공간이 충분합니다."},
  "data_source": [{"name": "건축물대장", "url": "https://www.gov.kr"}],
  "priority": "상",
  "f02_code": "resale-002",
  "f02_risk_axis": "resale"
},
{
  "category": "물건 기본 필터링",
  "question": "해당 물건이 반지하 빌라입니까?",
  "description": "반지하 빌라는 침수 위험, 채광 불량, 매매 난이도가 높아 초보 투자자에게 부적합합니다.",
  "logic": {"yes": "매매/임대가 매우 어렵습니다.", "no": "반지하가 아닙니다."},
  "data_source": [{"name": "경매정보지", "url": null}],
  "priority": "상",
  "f02_code": "resale-003",
  "f02_risk_axis": "resale"
},
{
  "category": "물건 기본 필터링",
  "question": "해당 빌라가 준공 2년 이내 신축이면서 감정가가 주변 시세보다 현저히 높습니까?",
  "description": "신축 빌라 중 감정가가 부풀려진 물건은 낙찰 후 시세보다 비싸게 사는 결과가 됩니다.",
  "logic": {"yes": "감정가 과대로 손해를 볼 수 있습니다.", "no": "신축빌라 리스크가 없습니다."},
  "data_source": [{"name": "건축물대장", "url": "https://www.gov.kr"}],
  "priority": "상",
  "f02_code": "resale-004",
  "f02_risk_axis": "resale"
}
```

- [ ] **Step 2: Add seeding block to db/seeds.rb**

Append to `db/seeds.rb`:

```ruby
puts "Seeding checklist items..."
RISK_AXIS_MAP = {
  "legal" => "legal",
  "resale" => "resale",
  "loan" => "loan"
}.freeze

F02_ITEMS = {
  "rights-011" => { risk_axis: "legal", position: 1 },
  "rights-002" => { risk_axis: "legal", position: 2 },
  "rights-019" => { risk_axis: "legal", position: 3 },
  "rights-020" => { risk_axis: "legal", position: 4 },
  "rights-003" => { risk_axis: "legal", position: 5 },
  "rights-006" => { risk_axis: "legal", position: 6 },
  "rights-014" => { risk_axis: "legal", position: 7 },
  "manual-001" => { risk_axis: "legal", position: 8 },
  "property-001" => { risk_axis: "legal", position: 9 },
  "property-005" => { risk_axis: "resale", position: 10 },
  "resale-001" => { risk_axis: "resale", position: 11 },
  "resale-002" => { risk_axis: "resale", position: 12 },
  "resale-003" => { risk_axis: "resale", position: 13 },
  "resale-004" => { risk_axis: "resale", position: 14 },
  "property-004" => { risk_axis: "loan", position: 15 },
  "rights-005" => { risk_axis: "loan", position: 16 },
  "property-002" => { risk_axis: "loan", position: 17 }
}.freeze

checklist_data = JSON.parse(File.read(Rails.root.join("db/seeds/checklist_items_summary.json")))
checklist_data.each do |attrs|
  code = attrs["f02_code"] || attrs.values_at("category", "question").join("-").parameterize[0..30]

  f02_config = F02_ITEMS[code]
  next unless f02_config

  ChecklistItem.find_or_create_by!(code: code) do |item|
    item.category = attrs["category"]
    item.risk_axis = f02_config[:risk_axis]
    item.question = attrs["question"]
    item.description = attrs["description"]
    item.logic = attrs["logic"]
    item.data_source_name = attrs.dig("data_source", 0, "name") || "수동 입력"
    item.priority = attrs["priority"]
    item.position = f02_config[:position]
  end
end
puts "  -> #{ChecklistItem.count} checklist items"
```

- [ ] **Step 3: Run seed and verify**

Run: `bin/rails db:seed`
Expected: "17 checklist items" printed

- [ ] **Step 4: Commit**

```bash
git add db/seeds/checklist_items_summary.json db/seeds.rb
git rm docs/checklist_items_summary.json
git commit -m "feat(f02): move checklist JSON to db/seeds, add 5 missing items, seed ChecklistItems"
```

---

## Phase 2: Adapters + Sync Service

### Task 6: Create CourtAuctionAdapter

**Files:**
- Create: `app/adapters/court_auction_adapter.rb`
- Create: `app/adapters/mock_court_auction_adapter.rb`
- Create: `app/adapters/government_court_auction_adapter.rb`
- Create: `test/adapters/court_auction_adapter_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
# test/adapters/court_auction_adapter_test.rb
require "test_helper"

class CourtAuctionAdapterTest < ActiveSupport::TestCase
  test ".for returns MockCourtAuctionAdapter by default" do
    adapter = CourtAuctionAdapter.for
    assert_instance_of MockCourtAuctionAdapter, adapter
  end

  test ".for returns GovernmentCourtAuctionAdapter when USE_MOCK is false" do
    ENV["USE_MOCK"] = "false"
    adapter = CourtAuctionAdapter.for
    assert_instance_of GovernmentCourtAuctionAdapter, adapter
  ensure
    ENV.delete("USE_MOCK")
  end

  test "mock adapter returns data for known case_number" do
    adapter = MockCourtAuctionAdapter.new
    data = adapter.fetch_data(case_number: "2026타경10001")
    assert data.is_a?(Hash)
    assert data.key?(:remarks)
    assert data.key?(:tenants)
  end

  test "mock adapter returns nil for unknown case_number" do
    adapter = MockCourtAuctionAdapter.new
    data = adapter.fetch_data(case_number: "unknown-999")
    assert_nil data
  end
end
```

- [ ] **Step 2: Implement adapters**

```ruby
# app/adapters/court_auction_adapter.rb
class CourtAuctionAdapter
  def self.for
    if ENV["USE_MOCK"] == "false"
      GovernmentCourtAuctionAdapter.new
    else
      MockCourtAuctionAdapter.new
    end
  end

  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end
end
```

```ruby
# app/adapters/mock_court_auction_adapter.rb
class MockCourtAuctionAdapter < CourtAuctionAdapter
  MOCK_DATA = {
    "2026타경10001" => {
      case_number: "2026타경10001",
      court_name: "서울중앙지방법원",
      property_type: "아파트",
      address: "서울특별시 강남구 역삼동 100-1",
      appraisal_price: 80000,
      min_bid_price: 56000,
      remarks: "해당사항 없음",
      non_extinguished_rights: [],
      tenants: [],
      separate_land_registry: false,
      lien_reported: false,
      use_approval: true,
      wall_partition_issue: false,
      is_partial_share: false
    },
    "2026타경10002" => {
      case_number: "2026타경10002",
      court_name: "수원지방법원",
      property_type: "빌라",
      address: "경기도 수원시 영통구 200-2",
      appraisal_price: 30000,
      min_bid_price: 21000,
      remarks: "유치권 신고 있음. 법정지상권 성립 가능성 있음.",
      non_extinguished_rights: [ "전세권" ],
      tenants: [
        { name: "김임차", deposit: nil, move_in_date: "2024-03-15", dividend_requested: false }
      ],
      separate_land_registry: true,
      lien_reported: true,
      use_approval: false,
      wall_partition_issue: true,
      is_partial_share: false
    },
    "2026타경10003" => {
      case_number: "2026타경10003",
      court_name: "인천지방법원",
      property_type: "오피스텔",
      address: "인천광역시 연수구 300-3",
      appraisal_price: 25000,
      min_bid_price: 17500,
      remarks: "해당사항 없음",
      non_extinguished_rights: [],
      tenants: [
        { name: "박세입", deposit: 5000, move_in_date: "2025-01-10", dividend_requested: true }
      ],
      separate_land_registry: false,
      lien_reported: false,
      use_approval: true,
      wall_partition_issue: false,
      is_partial_share: true
    }
  }.freeze

  def fetch_data(case_number:)
    MOCK_DATA[case_number]
  end
end
```

```ruby
# app/adapters/government_court_auction_adapter.rb
class GovernmentCourtAuctionAdapter < CourtAuctionAdapter
  def fetch_data(case_number:)
    # TODO: Replace with real courtauction.go.kr API calls
    MockCourtAuctionAdapter.new.fetch_data(case_number: case_number)
  end
end
```

- [ ] **Step 3: Run tests, commit**

Run: `bin/rails test test/adapters/court_auction_adapter_test.rb`

```bash
git add app/adapters/court_auction_adapter.rb app/adapters/mock_court_auction_adapter.rb app/adapters/government_court_auction_adapter.rb test/adapters/court_auction_adapter_test.rb
git commit -m "feat(f02): add CourtAuctionAdapter with mock data for 매각물건명세서"
```

---

### Task 7: Create BuildingLedgerAdapter

**Files:**
- Create: `app/adapters/building_ledger_adapter.rb`
- Create: `app/adapters/mock_building_ledger_adapter.rb`
- Create: `app/adapters/government_building_ledger_adapter.rb`
- Create: `test/adapters/building_ledger_adapter_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
# test/adapters/building_ledger_adapter_test.rb
require "test_helper"

class BuildingLedgerAdapterTest < ActiveSupport::TestCase
  test ".for returns MockBuildingLedgerAdapter by default" do
    adapter = BuildingLedgerAdapter.for
    assert_instance_of MockBuildingLedgerAdapter, adapter
  end

  test "mock adapter returns building data for known case_number" do
    adapter = MockBuildingLedgerAdapter.new
    data = adapter.fetch_data(case_number: "2026타경10002")
    assert data.is_a?(Hash)
    assert data.key?(:usage_type)
    assert data.key?(:violation_flag)
  end
end
```

- [ ] **Step 2: Implement adapters**

```ruby
# app/adapters/building_ledger_adapter.rb
class BuildingLedgerAdapter
  def self.for
    if ENV["USE_MOCK"] == "false"
      GovernmentBuildingLedgerAdapter.new
    else
      MockBuildingLedgerAdapter.new
    end
  end

  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end
end
```

```ruby
# app/adapters/mock_building_ledger_adapter.rb
class MockBuildingLedgerAdapter < BuildingLedgerAdapter
  MOCK_DATA = {
    "2026타경10001" => {
      usage_type: "아파트",
      violation_flag: false,
      completion_date: "2015-06-20",
      room_count: 3,
      floor_info: "5층",
      parking_per_unit: 1.2,
      total_units: 200
    },
    "2026타경10002" => {
      usage_type: "근린생활시설",
      violation_flag: true,
      completion_date: "2025-03-01",
      room_count: 1,
      floor_info: "반지하",
      parking_per_unit: 0.3,
      total_units: 12
    },
    "2026타경10003" => {
      usage_type: "사무소",
      violation_flag: false,
      completion_date: "2020-11-15",
      room_count: 1,
      floor_info: "8층",
      parking_per_unit: 0.8,
      total_units: 50
    }
  }.freeze

  def fetch_data(case_number:)
    MOCK_DATA[case_number]
  end
end
```

```ruby
# app/adapters/government_building_ledger_adapter.rb
class GovernmentBuildingLedgerAdapter < BuildingLedgerAdapter
  def fetch_data(case_number:)
    MockBuildingLedgerAdapter.new.fetch_data(case_number: case_number)
  end
end
```

- [ ] **Step 3: Run tests, commit**

Run: `bin/rails test test/adapters/building_ledger_adapter_test.rb`

```bash
git add app/adapters/building_ledger_adapter.rb app/adapters/mock_building_ledger_adapter.rb app/adapters/government_building_ledger_adapter.rb test/adapters/building_ledger_adapter_test.rb
git commit -m "feat(f02): add BuildingLedgerAdapter with mock data for 건축물대장"
```

---

### Task 8: Create PropertyDataSyncService

**Files:**
- Create: `app/services/property_data_sync_service.rb`
- Create: `test/services/property_data_sync_service_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
# test/services/property_data_sync_service_test.rb
require "test_helper"

class PropertyDataSyncServiceTest < ActiveSupport::TestCase
  test "creates new property from adapters" do
    assert_difference "Property.count", 1 do
      property = PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_equal "2026타경10001", property.case_number
      assert_equal "서울중앙지방법원", property.court_name
      assert property.raw_data.key?("court_auction")
      assert property.raw_data.key?("building_ledger")
    end
  end

  test "upserts existing property without duplicating" do
    PropertyDataSyncService.call(case_number: "2026타경10001")
    assert_no_difference "Property.count" do
      property = PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_equal "2026타경10001", property.case_number
    end
  end

  test "stores raw_data from both adapters" do
    property = PropertyDataSyncService.call(case_number: "2026타경10002")
    court_data = property.raw_data["court_auction"]
    building_data = property.raw_data["building_ledger"]

    assert court_data["remarks"].include?("유치권")
    assert_equal true, building_data["violation_flag"]
  end

  test "handles missing building ledger data gracefully" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    assert property.raw_data.key?("building_ledger")
  end
end
```

- [ ] **Step 2: Implement service**

```ruby
# app/services/property_data_sync_service.rb
class PropertyDataSyncService
  def self.call(case_number:)
    new(case_number:).call
  end

  def initialize(case_number:)
    @case_number = case_number
  end

  def call
    court_data = CourtAuctionAdapter.for.fetch_data(case_number: @case_number)
    building_data = BuildingLedgerAdapter.for.fetch_data(case_number: @case_number)

    return nil unless court_data

    property = Property.find_or_initialize_by(case_number: @case_number)
    property.assign_attributes(
      court_name: court_data[:court_name],
      property_type: court_data[:property_type],
      address: court_data[:address],
      appraisal_price: court_data[:appraisal_price],
      min_bid_price: court_data[:min_bid_price],
      raw_data: {
        court_auction: court_data.deep_stringify_keys,
        building_ledger: building_data&.deep_stringify_keys
      }
    )
    property.save!
    property
  end
end
```

- [ ] **Step 3: Run tests, commit**

Run: `bin/rails test test/services/property_data_sync_service_test.rb`

```bash
git add app/services/property_data_sync_service.rb test/services/property_data_sync_service_test.rb
git commit -m "feat(f02): add PropertyDataSyncService with dual-adapter upsert"
```

---

## Phase 3: Analysis Services

### Task 9: Create AutoCheckRunner

**Files:**
- Create: `app/services/auto_check_runner.rb`
- Create: `test/services/auto_check_runner_test.rb`

- [ ] **Step 1: Write failing test for basic execution**

```ruby
# test/services/auto_check_runner_test.rb
require "test_helper"

class AutoCheckRunnerTest < ActiveSupport::TestCase
  setup do
    @safe_property = PropertyDataSyncService.call(case_number: "2026타경10001")
    @risky_property = PropertyDataSyncService.call(case_number: "2026타경10002")
  end

  test "creates PropertyCheckResult for each F02 ChecklistItem" do
    results = AutoCheckRunner.call(property: @safe_property)
    assert_equal ChecklistItem.count, results.size
  end

  test "detects 유치권/법정지상권 in remarks (rights-011)" do
    AutoCheckRunner.call(property: @risky_property)
    result = @risky_property.property_check_results.joins(:checklist_item).find_by(checklist_items: { code: "rights-011" })
    assert result.auto?
    assert result.has_risk
  end

  test "no risk for safe property remarks (rights-011)" do
    AutoCheckRunner.call(property: @safe_property)
    result = @safe_property.property_check_results.joins(:checklist_item).find_by(checklist_items: { code: "rights-011" })
    assert result.auto?
    assert_not result.has_risk
  end

  test "detects 위반건축물 from building ledger (property-004)" do
    AutoCheckRunner.call(property: @risky_property)
    result = @risky_property.property_check_results.joins(:checklist_item).find_by(checklist_items: { code: "property-004" })
    assert result.has_risk
  end

  test "items without data get nil source_type" do
    AutoCheckRunner.call(property: @safe_property)
    manual_result = @safe_property.property_check_results.joins(:checklist_item).find_by(checklist_items: { code: "manual-001" })
    assert_nil manual_result.source_type
  end
end
```

- [ ] **Step 2: Implement AutoCheckRunner**

```ruby
# app/services/auto_check_runner.rb
class AutoCheckRunner
  DETECTION_RULES = {
    "rights-011" => ->(raw) { raw.dig("court_auction", "remarks")&.match?(/유치권|법정지상권/) },
    "rights-002" => ->(raw) { raw.dig("court_auction", "non_extinguished_rights")&.any? },
    "rights-019" => ->(raw) { raw.dig("court_auction", "separate_land_registry") == true },
    "rights-020" => ->(raw) { raw.dig("court_auction", "lien_reported") == true },
    "rights-003" => ->(raw) { raw.dig("court_auction", "tenants")&.any? },
    "rights-006" => ->(raw) {
      tenants = raw.dig("court_auction", "tenants") || []
      tenants.any? { |t| t["dividend_requested"] == false }
    },
    "rights-014" => ->(raw) {
      tenants = raw.dig("court_auction", "tenants") || []
      tenants.any? { |t| t["deposit"].nil? || t["dividend_requested"] == false }
    },
    "manual-001" => nil,
    "property-001" => ->(raw) { raw.dig("court_auction", "is_partial_share") == true },
    "property-005" => ->(raw) { raw.dig("building_ledger", "usage_type") == "사무소" },
    "resale-001" => ->(raw) { (raw.dig("building_ledger", "room_count") || 99) <= 1 },
    "resale-002" => ->(raw) { (raw.dig("building_ledger", "parking_per_unit") || 99) < 0.5 },
    "resale-003" => ->(raw) { raw.dig("building_ledger", "floor_info")&.include?("반지하") },
    "resale-004" => ->(raw) {
      completion = raw.dig("building_ledger", "completion_date")
      return nil unless completion
      Date.parse(completion) > 2.years.ago.to_date
    },
    "property-004" => ->(raw) { raw.dig("building_ledger", "violation_flag") == true },
    "rights-005" => ->(raw) { raw.dig("court_auction", "use_approval") == false },
    "property-002" => ->(raw) { raw.dig("court_auction", "wall_partition_issue") == true }
  }.freeze

  def self.call(property:)
    new(property:).call
  end

  def initialize(property:)
    @property = property
  end

  def call
    raw = @property.raw_data || {}

    ChecklistItem.ordered.map do |item|
      rule = DETECTION_RULES[item.code]
      result = @property.property_check_results.find_or_initialize_by(checklist_item: item)

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

- [ ] **Step 3: Run tests, commit**

Run: `bin/rails test test/services/auto_check_runner_test.rb`

```bash
git add app/services/auto_check_runner.rb test/services/auto_check_runner_test.rb
git commit -m "feat(f02): add AutoCheckRunner with 17 detection rules for risk analysis"
```

---

### Task 10: Create SafetyRatingService

**Files:**
- Create: `app/services/safety_rating_service.rb`
- Create: `test/services/safety_rating_service_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
# test/services/safety_rating_service_test.rb
require "test_helper"

class SafetyRatingServiceTest < ActiveSupport::TestCase
  test "rates safe when no risks" do
    property = properties(:safe_apartment)
    property.property_check_results.update_all(has_risk: false)

    SafetyRatingService.call(property: property)
    assert_equal "safe", property.reload.safety_rating
  end

  test "rates caution when risks are all resolvable" do
    property = properties(:safe_apartment)
    property.property_check_results.where(has_risk: true).update_all(resolvable: true)

    SafetyRatingService.call(property: property)
    assert_equal "caution", property.reload.safety_rating
  end

  test "rates danger when any risk is unresolvable" do
    property = properties(:risky_villa)
    # risky_villa fixture has has_risk: true, resolvable: false
    SafetyRatingService.call(property: property)
    assert_equal "danger", property.reload.safety_rating
  end
end
```

- [ ] **Step 2: Implement service**

```ruby
# app/services/safety_rating_service.rb
class SafetyRatingService
  def self.call(property:)
    new(property:).call
  end

  def initialize(property:)
    @property = property
  end

  def call
    results = @property.property_check_results.where(has_risk: true)

    rating = if results.exists?(resolvable: false)
      :danger
    elsif results.any?
      :caution
    else
      :safe
    end

    @property.update!(safety_rating: rating)
    rating
  end
end
```

- [ ] **Step 3: Run tests, commit**

Run: `bin/rails test test/services/safety_rating_service_test.rb`

```bash
git add app/services/safety_rating_service.rb test/services/safety_rating_service_test.rb
git commit -m "feat(f02): add SafetyRatingService with 3-tier rating logic"
```

---

### Task 11: Create PropertyAnalysisService

**Files:**
- Create: `app/services/property_analysis_service.rb`
- Create: `test/services/property_analysis_service_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
# test/services/property_analysis_service_test.rb
require "test_helper"

class PropertyAnalysisServiceTest < ActiveSupport::TestCase
  test "creates check results for property" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")

    assert_difference "PropertyCheckResult.count", ChecklistItem.count do
      PropertyAnalysisService.call(property: property)
    end
  end

  test "returns hash with results and pending_manual_items" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    result = PropertyAnalysisService.call(property: property)

    assert result.key?(:results)
    assert result.key?(:pending_manual_items)
  end

  test "identifies items needing manual input" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    result = PropertyAnalysisService.call(property: property)

    # manual-001 (분묘기지권) always needs manual input
    manual_codes = result[:pending_manual_items].map { |r| r.checklist_item.code }
    assert_includes manual_codes, "manual-001"
  end
end
```

- [ ] **Step 2: Implement service**

```ruby
# app/services/property_analysis_service.rb
class PropertyAnalysisService
  def self.call(property:)
    new(property:).call
  end

  def initialize(property:)
    @property = property
  end

  def call
    results = AutoCheckRunner.call(property: @property)
    pending = results.select { |r| r.source_type.nil? }

    { results: results, pending_manual_items: pending }
  end
end
```

- [ ] **Step 3: Run tests, commit**

Run: `bin/rails test test/services/property_analysis_service_test.rb`

```bash
git add app/services/property_analysis_service.rb test/services/property_analysis_service_test.rb
git commit -m "feat(f02): add PropertyAnalysisService orchestrating auto-check and manual input detection"
```

---

## Phase 4: Routes + Controllers

### Task 12: Add Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add routes**

Add to `config/routes.rb`, replacing `root "home#index"`:

```ruby
root "properties#index"

resources :properties, only: [ :index, :show ] do
  namespace :analyses do
    resource :start, only: [ :create ], controller: "start"
    resource :manual_input, only: [ :edit, :update ], controller: "manual_inputs"
    resource :result, only: [ :edit, :update ], controller: "results"
    resource :rating, only: [ :show ], controller: "ratings"
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add config/routes.rb
git commit -m "feat(f02): add property and analysis routes, change root to properties#index"
```

---

### Task 13: Create PropertiesController

**Files:**
- Create: `app/controllers/properties_controller.rb`
- Create: `test/controllers/properties_controller_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
# test/controllers/properties_controller_test.rb
require "test_helper"

class PropertiesControllerTest < ActionDispatch::IntegrationTest
  test "GET index returns success" do
    get properties_url
    assert_response :success
  end

  test "GET index filters by safety_rating" do
    get properties_url(safety_rating: "safe")
    assert_response :success
  end

  test "GET show returns success" do
    property = properties(:safe_apartment)
    get property_url(property)
    assert_response :success
  end
end
```

- [ ] **Step 2: Implement controller**

```ruby
# app/controllers/properties_controller.rb
class PropertiesController < ApplicationController
  def index
    @properties = Property.all.order(created_at: :desc)
    @properties = @properties.where(safety_rating: params[:safety_rating]) if params[:safety_rating].present?
    @properties = @properties.where("min_bid_price <= ?", current_user.budget_setting.max_bid_amount) if current_user.budget_setting&.completed?
  end

  def show
    @property = Property.find(params[:id])
    @check_results = @property.property_check_results.includes(:checklist_item).order("checklist_items.position")
  end
end
```

- [ ] **Step 3: Create placeholder views**

```erb
<%# app/views/properties/index.html.erb %>
<h1>물건 목록</h1>
<% @properties.each do |property| %>
  <div><%= link_to property.case_number, property_path(property) %></div>
<% end %>
```

```erb
<%# app/views/properties/show.html.erb %>
<h1><%= @property.case_number %></h1>
<p><%= @property.address %></p>
```

- [ ] **Step 4: Run tests, commit**

Run: `bin/rails test test/controllers/properties_controller_test.rb`

```bash
git add app/controllers/properties_controller.rb test/controllers/properties_controller_test.rb app/views/properties/
git commit -m "feat(f02): add PropertiesController with index filtering and show"
```

---

### Task 14: Create Analyses::StartController

**Files:**
- Create: `app/controllers/analyses/start_controller.rb`
- Create: `test/controllers/analyses/start_controller_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
# test/controllers/analyses/start_controller_test.rb
require "test_helper"

class Analyses::StartControllerTest < ActionDispatch::IntegrationTest
  test "POST create runs analysis and redirects to manual_inputs when needed" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    post property_analyses_start_url(property)
    assert_redirected_to edit_property_analyses_manual_input_url(property)
  end

  test "POST create redirects to results when no manual input needed" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    # Pre-fill all manual items
    PropertyAnalysisService.call(property: property)
    property.property_check_results.where(source_type: nil).update_all(source_type: 1, has_risk: false)

    post property_analyses_start_url(property)
    assert_redirected_to edit_property_analyses_result_url(property)
  end
end
```

- [ ] **Step 2: Implement controller**

```ruby
# app/controllers/analyses/start_controller.rb
module Analyses
  class StartController < ApplicationController
    def create
      @property = Property.find(params[:property_id])
      result = PropertyAnalysisService.call(property: @property)

      if result[:pending_manual_items].any?
        redirect_to edit_property_analyses_manual_input_url(@property)
      else
        redirect_to edit_property_analyses_result_url(@property)
      end
    end
  end
end
```

- [ ] **Step 3: Run tests, commit**

Run: `bin/rails test test/controllers/analyses/start_controller_test.rb`

```bash
git add app/controllers/analyses/start_controller.rb test/controllers/analyses/start_controller_test.rb
git commit -m "feat(f02): add Analyses::StartController triggering analysis flow"
```

---

### Task 15: Create Analyses::ManualInputsController

**Files:**
- Create: `app/controllers/analyses/manual_inputs_controller.rb`
- Create: `test/controllers/analyses/manual_inputs_controller_test.rb`
- Create: `app/views/analyses/manual_inputs/edit.html.erb`

- [ ] **Step 1: Write failing test**

```ruby
# test/controllers/analyses/manual_inputs_controller_test.rb
require "test_helper"

class Analyses::ManualInputsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = PropertyDataSyncService.call(case_number: "2026타경10001")
    PropertyAnalysisService.call(property: @property)
  end

  test "GET edit shows pending manual items" do
    get edit_property_analyses_manual_input_url(@property)
    assert_response :success
  end

  test "PATCH update saves manual values and redirects to results" do
    pending_ids = @property.property_check_results.where(source_type: nil).pluck(:id)
    answers = pending_ids.index_with { |_id| { has_risk: "false", manual_value: "no" } }

    patch property_analyses_manual_input_url(@property), params: { check_results: answers }
    assert_redirected_to edit_property_analyses_result_url(@property)

    @property.property_check_results.where(id: pending_ids).each do |r|
      assert r.manual?
    end
  end
end
```

- [ ] **Step 2: Implement controller**

```ruby
# app/controllers/analyses/manual_inputs_controller.rb
module Analyses
  class ManualInputsController < ApplicationController
    def edit
      @property = Property.find(params[:property_id])
      @pending_results = @property.property_check_results
        .where(source_type: nil)
        .includes(:checklist_item)
        .order("checklist_items.position")
    end

    def update
      @property = Property.find(params[:property_id])
      check_results_params = params.expect(check_results: {})

      check_results_params.each do |id, values|
        result = @property.property_check_results.find(id)
        result.update!(
          source_type: "manual",
          manual_value: values[:manual_value],
          has_risk: values[:has_risk] == "true"
        )
      end

      redirect_to edit_property_analyses_result_url(@property)
    end
  end
end
```

- [ ] **Step 3: Create placeholder view**

```erb
<%# app/views/analyses/manual_inputs/edit.html.erb %>
<%= turbo_frame_tag "analysis_flow" do %>
  <h2>수동 입력이 필요한 항목</h2>
  <%= form_with url: property_analyses_manual_input_path(@property), method: :patch do |f| %>
    <% @pending_results.each do |result| %>
      <div>
        <p><%= result.checklist_item.question %></p>
        <%= hidden_field_tag "check_results[#{result.id}][manual_value]", "" %>
        <label><%= radio_button_tag "check_results[#{result.id}][has_risk]", "true" %> 예</label>
        <label><%= radio_button_tag "check_results[#{result.id}][has_risk]", "false" %> 아니오</label>
      </div>
    <% end %>
    <%= f.submit "완료" %>
  <% end %>
<% end %>
```

- [ ] **Step 4: Run tests, commit**

Run: `bin/rails test test/controllers/analyses/manual_inputs_controller_test.rb`

```bash
git add app/controllers/analyses/manual_inputs_controller.rb test/controllers/analyses/manual_inputs_controller_test.rb app/views/analyses/manual_inputs/
git commit -m "feat(f02): add ManualInputsController for user-driven risk data entry"
```

---

### Task 16: Create Analyses::ResultsController

**Files:**
- Create: `app/controllers/analyses/results_controller.rb`
- Create: `test/controllers/analyses/results_controller_test.rb`
- Create: `app/views/analyses/results/edit.html.erb`

- [ ] **Step 1: Write failing test**

```ruby
# test/controllers/analyses/results_controller_test.rb
require "test_helper"

class Analyses::ResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = PropertyDataSyncService.call(case_number: "2026타경10002")
    PropertyAnalysisService.call(property: @property)
    @property.property_check_results.where(source_type: nil).update_all(source_type: 1, has_risk: false)
  end

  test "GET edit shows all check results grouped by risk axis" do
    get edit_property_analyses_result_url(@property)
    assert_response :success
  end

  test "PATCH update saves resolvable and redirects to rating" do
    risk_results = @property.property_check_results.where(has_risk: true)
    resolutions = risk_results.index_with { |_r| { resolvable: "false", resolution_note: "해결 불가" } }

    patch property_analyses_result_url(@property), params: { resolutions: resolutions.transform_keys(&:id) }
    assert_redirected_to property_analyses_rating_url(@property)
  end
end
```

- [ ] **Step 2: Implement controller**

```ruby
# app/controllers/analyses/results_controller.rb
module Analyses
  class ResultsController < ApplicationController
    def edit
      @property = Property.find(params[:property_id])
      @results_by_axis = @property.property_check_results
        .includes(:checklist_item)
        .order("checklist_items.position")
        .group_by { |r| r.checklist_item.risk_axis }
    end

    def update
      @property = Property.find(params[:property_id])
      resolution_params = params.expect(resolutions: {})

      resolution_params.each do |id, values|
        result = @property.property_check_results.find(id)
        result.update!(
          resolvable: values[:resolvable] == "true",
          resolution_note: values[:resolution_note]
        )
      end

      redirect_to property_analyses_rating_url(@property)
    end
  end
end
```

- [ ] **Step 3: Create placeholder view**

```erb
<%# app/views/analyses/results/edit.html.erb %>
<%= turbo_frame_tag "analysis_flow" do %>
  <h2>분석 결과</h2>
  <%= form_with url: property_analyses_result_path(@property), method: :patch do |f| %>
    <% @results_by_axis.each do |axis, results| %>
      <h3><%= { "legal" => "법적 위험", "resale" => "매도 위험", "loan" => "대출 위험" }[axis] %></h3>
      <% results.each do |result| %>
        <div>
          <p><%= result.checklist_item.question %></p>
          <p><%= result.has_risk ? "⚠️ 위험" : "✅ 안전" %></p>
          <% if result.has_risk %>
            <label><%= radio_button_tag "resolutions[#{result.id}][resolvable]", "true" %> 해결 가능</label>
            <label><%= radio_button_tag "resolutions[#{result.id}][resolvable]", "false" %> 해결 불가</label>
            <%= text_field_tag "resolutions[#{result.id}][resolution_note]", "", placeholder: "해결 방안 메모" %>
          <% end %>
        </div>
      <% end %>
    <% end %>
    <%= f.submit "등급 산정" %>
  <% end %>
<% end %>
```

- [ ] **Step 4: Run tests, commit**

Run: `bin/rails test test/controllers/analyses/results_controller_test.rb`

```bash
git add app/controllers/analyses/results_controller.rb test/controllers/analyses/results_controller_test.rb app/views/analyses/results/
git commit -m "feat(f02): add ResultsController for resolution input and risk review"
```

---

### Task 17: Create Analyses::RatingsController

**Files:**
- Create: `app/controllers/analyses/ratings_controller.rb`
- Create: `test/controllers/analyses/ratings_controller_test.rb`
- Create: `app/views/analyses/ratings/show.html.erb`

- [ ] **Step 1: Write failing test**

```ruby
# test/controllers/analyses/ratings_controller_test.rb
require "test_helper"

class Analyses::RatingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = PropertyDataSyncService.call(case_number: "2026타경10001")
    PropertyAnalysisService.call(property: @property)
    @property.property_check_results.where(source_type: nil).update_all(source_type: 1, has_risk: false)
  end

  test "GET show calculates rating and displays result" do
    get property_analyses_rating_url(@property)
    assert_response :success
    assert_equal "safe", @property.reload.safety_rating
  end
end
```

- [ ] **Step 2: Implement controller**

```ruby
# app/controllers/analyses/ratings_controller.rb
module Analyses
  class RatingsController < ApplicationController
    def show
      @property = Property.find(params[:property_id])
      @rating = SafetyRatingService.call(property: @property)
      @risk_results = @property.property_check_results
        .where(has_risk: true)
        .includes(:checklist_item)
        .order("checklist_items.position")
    end
  end
end
```

- [ ] **Step 3: Create placeholder view**

```erb
<%# app/views/analyses/ratings/show.html.erb %>
<%= turbo_frame_tag "analysis_flow" do %>
  <h2>안전 등급: <%= @property.safety_rating&.upcase %></h2>
  <% if @risk_results.any? %>
    <h3>위험 항목</h3>
    <% @risk_results.each do |result| %>
      <div>
        <p><%= result.checklist_item.question %></p>
        <p><%= result.resolvable ? "해결 가능" : "해결 불가" %></p>
      </div>
    <% end %>
  <% end %>
  <%= link_to "목록으로 돌아가기", properties_path %>
  <%= link_to "다시 분석하기", property_path(@property) %>
<% end %>
```

- [ ] **Step 4: Run tests, commit**

Run: `bin/rails test test/controllers/analyses/ratings_controller_test.rb`

```bash
git add app/controllers/analyses/ratings_controller.rb test/controllers/analyses/ratings_controller_test.rb app/views/analyses/ratings/
git commit -m "feat(f02): add RatingsController with safety rating display"
```

---

## Phase 5: ViewComponents

### Task 18: Create SafetyBadgeComponent

**Files:**
- Create: `app/components/safety_badge_component.rb`
- Create: `test/components/safety_badge_component_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
# test/components/safety_badge_component_test.rb
require "test_helper"

class SafetyBadgeComponentTest < ViewComponent::TestCase
  test "renders safe badge" do
    render_inline(SafetyBadgeComponent.new(rating: "safe"))
    assert_selector ".inline-flex", text: "Safe"
  end

  test "renders caution badge" do
    render_inline(SafetyBadgeComponent.new(rating: "caution"))
    assert_selector ".inline-flex", text: "Caution"
  end

  test "renders danger badge" do
    render_inline(SafetyBadgeComponent.new(rating: "danger"))
    assert_selector ".inline-flex", text: "Danger"
  end

  test "renders unanalyzed badge for nil rating" do
    render_inline(SafetyBadgeComponent.new(rating: nil))
    assert_selector ".inline-flex", text: "미분석"
  end
end
```

- [ ] **Step 2: Implement component**

```ruby
# app/components/safety_badge_component.rb
# frozen_string_literal: true

class SafetyBadgeComponent < ViewComponent::Base
  RATING_CONFIG = {
    "safe" => { variant: :success, label: "Safe" },
    "caution" => { variant: :warning, label: "Caution" },
    "danger" => { variant: :danger, label: "Danger" },
    nil => { variant: :default, label: "미분석" }
  }.freeze

  def initialize(rating:)
    @config = RATING_CONFIG[rating] || RATING_CONFIG[nil]
  end

  def call
    render BadgeComponent.new(variant: @config[:variant]) do
      @config[:label]
    end
  end
end
```

- [ ] **Step 3: Run tests, commit**

Run: `bin/rails test test/components/safety_badge_component_test.rb`

```bash
git add app/components/safety_badge_component.rb test/components/safety_badge_component_test.rb
git commit -m "feat(f02): add SafetyBadgeComponent wrapping BadgeComponent with rating config"
```

---

### Task 19-22: Remaining ViewComponents

Tasks 19-22 follow the same TDD pattern as Task 18. Each creates one ViewComponent with test → implementation → commit. Due to the plan's length constraints, these follow the same structure:

**Task 19: PropertyCardComponent** — Wraps CardComponent, displays case_number, address, formatted prices, SafetyBadge. Test verifies number formatting and badge rendering.

**Task 20: ChecklistItemComponent** — Renders question text, risk status icon (green check / red warning), and conditional resolution input fields (resolvable toggle + note textarea) when `has_risk: true`.

**Task 21: ChecklistGroupComponent** — Uses `renders_many :items` to wrap ChecklistItemComponents under a risk axis section header (법적 위험 / 매도 위험 / 대출 위험).

**Task 22: RatingResultComponent** — Large rating badge + justification list. Maps risk items to human-readable summary. Accordion for detailed per-item breakdown using `<details>/<summary>` tags.

Each task: write test → implement → commit. Reference `app/components/badge_component.rb` and `app/components/card_component.rb` for Tailwind patterns, dark mode classes, and `class_names()` usage.

---

## Phase 6: Views + Stimulus

### Task 23: Build properties/index View with UI Components

**Files:**
- Modify: `app/views/properties/index.html.erb`
- Reference: `/rails-ui` skill for design tokens

- [ ] **Step 1: Replace placeholder with full UI**

Replace the placeholder `properties/index.html.erb` with:
- Grid of PropertyCardComponents
- Filter bar with safety_rating dropdown + "Safe만 보기" button
- Turbo Frame for pagination
- Empty state when no properties found (reuse EmptyStateComponent)
- Invoke `/rails-ui` skill for design token compliance

- [ ] **Step 2: Commit**

```bash
git add app/views/properties/index.html.erb
git commit -m "feat(f02): build properties index view with card grid and filter UI"
```

---

### Task 24: Build properties/show View

**Files:**
- Modify: `app/views/properties/show.html.erb`

- [ ] **Step 1: Replace placeholder with full UI**

- Property detail card (address, prices, court, status)
- SafetyBadge display (if analyzed)
- "분석 시작" button (POST to analyses/start) inside `turbo_frame_tag "analysis_flow"`
- Already-analyzed state: show results summary with link to re-analyze

- [ ] **Step 2: Commit**

```bash
git add app/views/properties/show.html.erb
git commit -m "feat(f02): build property show view with analysis entry point"
```

---

### Task 25-27: Analysis Flow Views

**Task 25: analyses/manual_inputs/edit.html.erb** — Replace placeholder with ChecklistItemComponents in a form, Yes/No radio buttons, turbo_frame wrapper. Invoke `/rails-ui` skill.

**Task 26: analyses/results/edit.html.erb** — ChecklistGroupComponents for each risk axis. Resolution input only for risk items. Invoke `/rails-ui` skill.

**Task 27: analyses/ratings/show.html.erb** — RatingResultComponent with action buttons. Invoke `/rails-ui` skill.

---

### Task 28: Create manual-input Stimulus Controller

**Files:**
- Create: `app/javascript/controllers/manual_input_controller.js`

- [ ] **Step 1: Implement controller**

```javascript
// app/javascript/controllers/manual_input_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "radioGroup"]

  connect() {
    this.validate()
  }

  validate() {
    const groups = this.radioGroupTargets
    const allAnswered = groups.every(group => {
      return group.querySelector("input[type='radio']:checked") !== null
    })
    this.submitButtonTarget.disabled = !allAnswered
  }
}
```

- [ ] **Step 2: Wire to manual_inputs/edit.html.erb, commit**

```bash
git add app/javascript/controllers/manual_input_controller.js
git commit -m "feat(f02): add manual-input Stimulus controller for form validation"
```

---

### Task 29: Create resolution-input Stimulus Controller

**Files:**
- Create: `app/javascript/controllers/resolution_input_controller.js`

- [ ] **Step 1: Implement controller**

```javascript
// app/javascript/controllers/resolution_input_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["noteField"]

  toggle(event) {
    const resolvable = event.target.value === "true"
    const noteField = event.target.closest("[data-resolution-input-target='noteField']")
      || this.noteFieldTarget
    if (noteField) {
      noteField.classList.toggle("hidden", !resolvable)
    }
  }
}
```

- [ ] **Step 2: Wire to results/edit.html.erb, commit**

```bash
git add app/javascript/controllers/resolution_input_controller.js
git commit -m "feat(f02): add resolution-input Stimulus controller for note field toggle"
```

---

### Task 30: Create property-filter Stimulus Controller

**Files:**
- Create: `app/javascript/controllers/property_filter_controller.js`

- [ ] **Step 1: Implement controller**

```javascript
// app/javascript/controllers/property_filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["ratingSelect", "form"]

  safeOnly() {
    this.ratingSelectTarget.value = "safe"
    this.formTarget.requestSubmit()
  }

  clearFilter() {
    this.ratingSelectTarget.value = ""
    this.formTarget.requestSubmit()
  }
}
```

- [ ] **Step 2: Wire to properties/index.html.erb, commit**

```bash
git add app/javascript/controllers/property_filter_controller.js
git commit -m "feat(f02): add property-filter Stimulus controller with safe-only preset"
```

---

## Phase 7: Integration & Wiring

### Task 31: Update Navigation and Root Path

**Files:**
- Modify: sidebar navigation in layout
- Modify: `app/controllers/home_controller.rb`

- [ ] **Step 1: Update sidebar**

Update the sidebar navigation to show "물건 목록" as active link to `properties_path`. Keep existing "예산 설정" and other links. The home controller should redirect to `properties_path` if budget is completed, or to onboarding if not.

- [ ] **Step 2: Update HomeController**

```ruby
# app/controllers/home_controller.rb
class HomeController < ApplicationController
  def index
    if current_user.budget_setting&.completed?
      redirect_to properties_path
    else
      redirect_to start_onboarding_url
    end
  end
end
```

- [ ] **Step 3: Fix broken tests, commit**

Run: `bin/rails test`

```bash
git add app/controllers/home_controller.rb app/views/layouts/
git commit -m "feat(f02): update navigation and root path to properties index"
```

---

### Task 32: Seed Mock Properties

**Files:**
- Create: `db/seeds/mock_properties.json`
- Modify: `db/seeds.rb`

- [ ] **Step 1: Create mock property data**

```json
[
  { "case_number": "2026타경10001" },
  { "case_number": "2026타경10002" },
  { "case_number": "2026타경10003" }
]
```

- [ ] **Step 2: Add seeding block**

Append to `db/seeds.rb`:

```ruby
puts "Seeding mock properties..."
mock_properties = JSON.parse(File.read(Rails.root.join("db/seeds/mock_properties.json")))
mock_properties.each do |attrs|
  PropertyDataSyncService.call(case_number: attrs["case_number"])
end
puts "  -> #{Property.count} properties"
```

- [ ] **Step 3: Run seed, verify, commit**

Run: `bin/rails db:reset`

```bash
git add db/seeds/mock_properties.json db/seeds.rb
git commit -m "feat(f02): seed mock properties via PropertyDataSyncService"
```

---

### Task 33: End-to-End Integration Test

**Files:**
- Create: `test/integration/property_analysis_flow_test.rb`

- [ ] **Step 1: Write integration test**

```ruby
# test/integration/property_analysis_flow_test.rb
require "test_helper"

class PropertyAnalysisFlowTest < ActionDispatch::IntegrationTest
  test "full analysis flow: list → analyze → manual input → results → rating" do
    # Seed a property
    property = PropertyDataSyncService.call(case_number: "2026타경10002")

    # Visit list
    get properties_url
    assert_response :success

    # Visit property detail
    get property_url(property)
    assert_response :success

    # Start analysis
    post property_analyses_start_url(property)
    assert_response :redirect
    follow_redirect!
    assert_response :success

    # Fill manual inputs
    pending = property.property_check_results.where(source_type: nil)
    if pending.any?
      answers = pending.index_with { |_| { has_risk: "false", manual_value: "no" } }
      patch property_analyses_manual_input_url(property), params: { check_results: answers.transform_keys(&:id) }
      assert_response :redirect
      follow_redirect!
    end

    # Fill resolutions
    risk_results = property.property_check_results.where(has_risk: true)
    if risk_results.any?
      resolutions = risk_results.index_with { |_| { resolvable: "false", resolution_note: "해결 불가" } }
      patch property_analyses_result_url(property), params: { resolutions: resolutions.transform_keys(&:id) }
      assert_response :redirect
      follow_redirect!
    end

    # Verify rating
    get property_analyses_rating_url(property)
    assert_response :success
    assert property.reload.safety_rating.present?
  end
end
```

- [ ] **Step 2: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add test/integration/property_analysis_flow_test.rb
git commit -m "test(f02): add end-to-end integration test for property analysis flow"
```

---

## Verification

After all tasks are complete:

1. `bin/rails test` — all tests pass
2. `bin/rubocop` — no style violations
3. `bin/brakeman --quiet --no-pager` — no security warnings
4. `bin/rails db:reset && bin/rails db:seed` — seeds successfully
5. `bin/dev` — visit http://localhost:3000, verify:
   - Property list shows 3 mock properties with "미분석" badges
   - Click property → start analysis → manual input → results → rating
   - "Safe만 보기" filter works
   - Return to list shows updated badge
