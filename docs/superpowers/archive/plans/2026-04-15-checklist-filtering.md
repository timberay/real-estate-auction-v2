# Checklist Filtering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Filter checklist questions by property type and parent-child dependencies, and merge 8 duplicate questions (89 → 81), so users only see relevant questions.

**Architecture:** Two-layer filtering (static `applicable_types` at SQL level + dynamic `depends_on` at Ruby level) applied across 4 locations: LLM prompt builder, tab display controller, tab stats component, and grade rating service. Seed data updated to merge duplicates and add dependency relationships.

**Tech Stack:** Rails 8, SQLite, ViewComponent, Minitest

---

### Task 1: Migration — add `depends_on` column

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_depends_on_to_inspection_items.rb`

- [ ] **Step 1: Generate migration**

Run: `bin/rails generate migration AddDependsOnToInspectionItems depends_on:json`

- [ ] **Step 2: Run migration**

Run: `bin/rails db:migrate`
Expected: Schema updated with `depends_on` JSON column on `inspection_items`

- [ ] **Step 3: Verify schema**

Run: `bin/rails runner "puts InspectionItem.column_names.include?('depends_on')"`
Expected: `true`

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_add_depends_on_to_inspection_items.rb db/schema.rb
git commit -m "chore(db): add depends_on column to inspection_items"
```

---

### Task 2: Model — add `skip_for?`, `visible_for?`, `applicable_for_type` scope

**Files:**
- Modify: `app/models/inspection_item.rb`
- Modify: `test/models/inspection_item_test.rb`

- [ ] **Step 1: Write failing tests for `skip_for?`**

Add to `test/models/inspection_item_test.rb`:

```ruby
test "skip_for? returns false when depends_on is blank" do
  item = InspectionItem.new(code: "child-001", tab: "rights_analysis", tab_position: 1,
    category: "권리분석", question: "Q?", priority: "상", depends_on: nil)
  assert_equal false, item.skip_for?({})
end

test "skip_for? returns false when parent is unanswered (conservative)" do
  item = InspectionItem.new(code: "child-002", tab: "rights_analysis", tab_position: 1,
    category: "권리분석", question: "Q?", priority: "상",
    depends_on: { "code" => "rights-003", "show_when_risk" => true })
  # parent not in answered_results → show (conservative)
  assert_equal false, item.skip_for?({})
end

test "skip_for? returns false when parent has_risk is nil" do
  item = InspectionItem.new(code: "child-003", tab: "rights_analysis", tab_position: 1,
    category: "권리분석", question: "Q?", priority: "상",
    depends_on: { "code" => "parent-001", "show_when_risk" => true })
  parent_result = OpenStruct.new(has_risk: nil)
  assert_equal false, item.skip_for?({ "parent-001" => parent_result })
end

test "skip_for? returns true when parent has_risk does not match show_when_risk" do
  item = InspectionItem.new(code: "child-004", tab: "rights_analysis", tab_position: 1,
    category: "권리분석", question: "Q?", priority: "상",
    depends_on: { "code" => "parent-001", "show_when_risk" => true })
  parent_result = OpenStruct.new(has_risk: false)
  assert_equal true, item.skip_for?({ "parent-001" => parent_result })
end

test "skip_for? returns false when parent has_risk matches show_when_risk" do
  item = InspectionItem.new(code: "child-005", tab: "rights_analysis", tab_position: 1,
    category: "권리분석", question: "Q?", priority: "상",
    depends_on: { "code" => "parent-001", "show_when_risk" => true })
  parent_result = OpenStruct.new(has_risk: true)
  assert_equal false, item.skip_for?({ "parent-001" => parent_result })
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/inspection_item_test.rb`
Expected: 5 failures — `skip_for?` method not defined

- [ ] **Step 3: Write failing tests for `visible_for?`**

Add to `test/models/inspection_item_test.rb`:

```ruby
test "visible_for? returns true when applicable and not skipped" do
  item = InspectionItem.new(code: "vis-001", tab: "rights_analysis", tab_position: 1,
    category: "권리분석", question: "Q?", priority: "상",
    applicable_types: nil, depends_on: nil)
  assert item.visible_for?(property_type: "아파트", answered_results: {})
end

test "visible_for? returns false when not applicable for property type" do
  item = InspectionItem.new(code: "vis-002", tab: "rights_analysis", tab_position: 1,
    category: "권리분석", question: "Q?", priority: "상",
    applicable_types: ["상가"], depends_on: nil)
  refute item.visible_for?(property_type: "아파트", answered_results: {})
end

test "visible_for? returns false when skipped by parent dependency" do
  item = InspectionItem.new(code: "vis-003", tab: "rights_analysis", tab_position: 1,
    category: "권리분석", question: "Q?", priority: "상",
    applicable_types: nil,
    depends_on: { "code" => "parent-001", "show_when_risk" => true })
  parent_result = OpenStruct.new(has_risk: false)
  refute item.visible_for?(property_type: "아파트", answered_results: { "parent-001" => parent_result })
end
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `bin/rails test test/models/inspection_item_test.rb`
Expected: 3 additional failures — `visible_for?` method not defined

- [ ] **Step 5: Write failing test for `applicable_for_type` scope**

Add to `test/models/inspection_item_test.rb`:

```ruby
test "applicable_for_type scope returns items with nil applicable_types" do
  item = InspectionItem.create!(code: "scope-all", tab: "rights_analysis", tab_position: 99,
    category: "권리분석", question: "모든 타입?", priority: "상", applicable_types: nil)
  assert_includes InspectionItem.applicable_for_type("아파트"), item
end

test "applicable_for_type scope returns items matching the property type" do
  item = InspectionItem.create!(code: "scope-match", tab: "rights_analysis", tab_position: 99,
    category: "권리분석", question: "아파트 전용?", priority: "상", applicable_types: ["아파트", "오피스텔"])
  assert_includes InspectionItem.applicable_for_type("아파트"), item
  assert_not_includes InspectionItem.applicable_for_type("상가"), item
end

test "applicable_for_type scope returns all when property_type is blank" do
  item = InspectionItem.create!(code: "scope-blank", tab: "rights_analysis", tab_position: 99,
    category: "권리분석", question: "제한된 타입?", priority: "상", applicable_types: ["상가"])
  assert_includes InspectionItem.applicable_for_type(nil), item
  assert_includes InspectionItem.applicable_for_type(""), item
end
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `bin/rails test test/models/inspection_item_test.rb`
Expected: 3 additional failures — `applicable_for_type` scope not defined

- [ ] **Step 7: Implement all three methods**

Replace the full contents of `app/models/inspection_item.rb`:

```ruby
class InspectionItem < ApplicationRecord
  has_many :inspection_results, dependent: :destroy

  enum :tab, {
    rights_analysis: 0,   # 권리분석
    property_analysis: 1, # 물건분석
    profit_analysis: 2,   # 수익분석
    field_check: 3,       # 현장확인
    bidding: 4            # 입찰&낙찰
  }

  ANSWER_TYPES = %w[action_confirm].freeze

  validates :code, presence: true, uniqueness: true
  validates :tab, presence: true
  validates :question, presence: true
  validates :category, presence: true
  validates :answer_type, inclusion: { in: ANSWER_TYPES }, allow_nil: true

  scope :ordered, -> { order(:tab, :tab_position) }
  scope :for_tab, ->(tab) { where(tab: tab).order(:tab_position) }
  scope :applicable_for_type, ->(property_type) {
    return all if property_type.blank?
    where("applicable_types IS NULL OR EXISTS (SELECT 1 FROM json_each(applicable_types) WHERE json_each.value = ?)", property_type)
  }

  def applicable_for?(property_type)
    applicable_types.blank? || applicable_types.include?(property_type)
  end

  def visible_for?(property_type:, answered_results: {})
    applicable_for?(property_type) && !skip_for?(answered_results)
  end

  def skip_for?(answered_results_by_code)
    return false if depends_on.blank?

    parent_code = depends_on["code"]
    parent_result = answered_results_by_code[parent_code]

    return false if parent_result.nil? || parent_result.has_risk.nil?

    parent_result.has_risk != depends_on["show_when_risk"]
  end
end
```

- [ ] **Step 8: Run all tests to verify they pass**

Run: `bin/rails test test/models/inspection_item_test.rb`
Expected: All pass

- [ ] **Step 9: Commit**

```bash
git add app/models/inspection_item.rb test/models/inspection_item_test.rb
git commit -m "feat(model): add skip_for?, visible_for?, applicable_for_type to InspectionItem"
```

---

### Task 3: Seed data — merge 8 duplicate questions and add `depends_on`

**Files:**
- Modify: `db/seeds/checklist_items_summary.json`
- Modify: `test/fixtures/inspection_items.yml`
- Modify: `test/fixtures/files/ai_inspection_response.json`

This task modifies seed data only — no Ruby code changes.

- [ ] **Step 1: Delete 8 duplicate items and update absorbers in seed JSON**

Write a Python script `scripts/merge_checklist_items.py` to:

```python
import json

with open("db/seeds/checklist_items_summary.json", "r") as f:
    items = json.load(f)

# IDs to delete
DELETE_IDS = {"eviction-007", "rights-011", "market-004", "market-011",
              "regulation-001", "resale-002", "property-008", "finance-004"}

# Absorber updates: merge descriptions and logic
ABSORBER_UPDATES = {
    "eviction-003": {
        "description": "채무자 본인 / 임차인 / 가족 / 불법점유자 등 유형에 따라 법적 대응 방법과 명도 난이도가 완전히 다릅니다. 협의 명도 / 인도명령 / 강제집행 중 어떤 방식이 될지 사전 판단해야 비용·기간을 예측할 수 있습니다.",
        "merged_from": "eviction-002,eviction-007"
    },
    "rights-002": {
        "question": "매각물건명세서 '소멸되지 아니하는 것' 비고란에 낙찰자가 인수할 권리(가등기, 가처분, 전세권, 유치권, 법정지상권 등) 기재가 없는 깨끗한 물건입니까?",
        "description": "법원이 직접 '이 권리는 낙찰자가 떠안는다'고 명시한 것으로, 초보자에게 가장 위험한 함정입니다. 유치권은 공사대금 미지급 등으로 점유를 주장하는 것이고, 법정지상권은 토지와 건물 소유자가 달라질 때 발생합니다.",
        "merged_from": "rights-011"
    },
    "market-001": {
        "question": "최근 1년간 해당 지역 및 단지의 실거래가 활발하고, 최근 1개월 내 거래 내역이 있습니까?",
        "description": "거래량이 활발해야 매도 시 빠르게 현금화할 수 있습니다. 거래가 뜸한 지역은 유동성 리스크가 높습니다. 최근 1개월 실거래 유무로 현재의 거래 활성도를 교차 확인합니다.",
        "merged_from": "market-004"
    },
    "inspect-011": {
        "question": "실제 매도가에서 수리비와 실투자금을 바탕으로 순수익과 입찰가를 역산법으로 계산하여 흑자를 확인하였습니까?",
        "description": "감에 의한 입찰가 산정이 아닌, 역산법(예상 매도가 - 비용 = 수익 → 최대 입찰가)을 적용했는지 확인합니다. 순수익이 0원 이하이거나 경매 최저가가 시세에 근접하면 입찰 메리트가 없습니다.",
        "merged_from": "market-009,market-011,regulation-001"
    },
    "inspect-014": {
        "question": "건물 간격(뻥뷰), 조망, 세대수 대비 주차 공간이 양호합니까?",
        "description": "창문 앞이 바로 옆 건물 벽으로 막혀 있는 '벽뷰'는 일조량 부족과 답답함으로 매도가가 크게 하락합니다. 채광·조망이 차단된 물건은 시세 대비 20~30% 낮은 가격에도 매수자를 찾기 어렵습니다. 주차 공간이 협소하거나 없으면 임차인 구하기와 매도에 극심한 어려움을 겪습니다. 반드시 현장에서 확인해야 합니다.",
        "applicable_types": ["아파트", "빌라/다세대", "오피스텔", "단독주택"],
        "merged_from": "resale-002,property-008"
    },
    "tax-002": {
        "question": "매매사업자 또는 법인 명의로 입찰할 계획입니까?",
        "description": "개인/법인/공동명의에 따라 취득세·양도세·종합부동산세 부담이 완전히 달라집니다. 매매사업자 등록 시 취득세 중과 회피, 부가세 환급 등의 혜택이 있지만, 건강보험료 상승 등 부작용도 있어 사전 판단이 필요합니다.",
        "merged_from": "finance-004"
    }
}

# Add depends_on to child items
DEPENDS_ON = {
    "rights-016": {"code": "rights-003", "show_when_risk": True},
    "rights-015": {"code": "rights-003", "show_when_risk": True},
    "rights-006": {"code": "rights-003", "show_when_risk": True},
    "rights-009": {"code": "rights-003", "show_when_risk": True},
    "rights-010": {"code": "rights-003", "show_when_risk": True},
    "rights-014": {"code": "rights-003", "show_when_risk": True},
    "rights-012": {"code": "rights-003", "show_when_risk": True},
    "rights-013": {"code": "rights-003", "show_when_risk": True},
    "rights-017": {"code": "rights-008", "show_when_risk": True},
}

# Apply absorber updates
for item in items:
    item_id = item["id"]
    if item_id in ABSORBER_UPDATES:
        item.update(ABSORBER_UPDATES[item_id])
    if item_id in DEPENDS_ON:
        item["depends_on"] = DEPENDS_ON[item_id]

# Remove deleted items
items = [item for item in items if item["id"] not in DELETE_IDS]

print(f"Total items: {len(items)}")
print(f"Items with depends_on: {sum(1 for i in items if 'depends_on' in i)}")
print(f"Items with applicable_types: {sum(1 for i in items if i.get('applicable_types'))}")

with open("db/seeds/checklist_items_summary.json", "w") as f:
    json.dump(items, f, ensure_ascii=False, indent=2)
    f.write("\n")

print("Done.")
```

Run: `python3 scripts/merge_checklist_items.py`
Expected: `Total items: 81`, `Items with depends_on: 9`, `Items with applicable_types: 29`

- [ ] **Step 2: Update test fixtures**

In `test/fixtures/inspection_items.yml`, replace the `rights_011` fixture with a fixture for `rights-003` (needed as a parent for depends_on tests), and update `resale_002` to match the merged `inspect-014`:

Replace `rights_011` fixture:

```yaml
rights_003:
  code: "rights-003"
  tab: 0
  tab_position: 4
  category: "권리분석"
  question: "전입신고된 제3자 임차인이 거주하고 있습니까?"
  description: "임차인 확인"
  logic: '{"yes": "임차인 있음", "no": "없음"}'
  data_source_name: "수동 입력"
  priority: "상"
  yes_means_safe: false
```

Remove the `resale_002` fixture entirely (it's being deleted/merged).

- [ ] **Step 3: Update AI response test fixture**

In `test/fixtures/files/ai_inspection_response.json`, replace the `rights-011` key with `rights-003`:

Find:
```json
    "rights-011": {
```
Replace with:
```json
    "rights-003": {
```

(Keep the same has_risk/confidence/reasoning values — the tests reference this fixture by code.)

- [ ] **Step 4: Update test references to deleted codes**

In `test/services/inspection/inspection_result_mapper_test.rb`, replace the reference to `rights-011`:

Replace:
```ruby
  test "overwrites previous auto answers with ai" do
    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-011")
    assert result.ai?
  end
```

With:
```ruby
  test "overwrites previous auto answers with ai" do
    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-003")
    assert result.ai?
  end
```

In `test/services/inspection/pdf_prompt_builder_test.rb`, replace:

```ruby
  test "includes yes_means_safe and priority for each item" do
    items = InspectionItem.where(code: "rights-011").to_a
    result = Inspection::PdfPromptBuilder.call(items: items)

    assert result[:user].include?("yes_means_safe=false")
    assert result[:user].include?("priority=상")
  end
```

With:
```ruby
  test "includes yes_means_safe and priority for each item" do
    items = InspectionItem.where(code: "rights-008").to_a
    result = Inspection::PdfPromptBuilder.call(items: items)

    assert result[:user].include?("yes_means_safe=false")
    assert result[:user].include?("priority=상")
  end
```

(Uses `rights-008` which also has `yes_means_safe: false` and `priority: 상`.)

- [ ] **Step 5: Reseed the database**

Run: `bin/rails db:seed`
Expected: `81 inspection items (removed 8 stale)`

- [ ] **Step 6: Run all tests to verify nothing broke**

Run: `bin/rails test`
Expected: All pass

- [ ] **Step 7: Commit**

```bash
git add db/seeds/checklist_items_summary.json test/fixtures/ scripts/merge_checklist_items.py
git commit -m "refactor(seed): merge 8 duplicate questions (89→81) and add depends_on"
```

---

### Task 4: Seed loader — load `depends_on` from JSON

**Files:**
- Modify: `db/seeds.rb`

- [ ] **Step 1: Add `depends_on` to seed loader**

In `db/seeds.rb`, add `depends_on` to the `assign_attributes` call inside the `inspection_data.each` block:

Find:
```ruby
    applicable_types: attrs["applicable_types"]
```

Replace with:
```ruby
    applicable_types: attrs["applicable_types"],
    depends_on: attrs["depends_on"]
```

- [ ] **Step 2: Reseed and verify**

Run: `bin/rails db:seed`
Then: `bin/rails runner "puts InspectionItem.where.not(depends_on: nil).pluck(:code, :depends_on).inspect"`
Expected: 9 items with depends_on — the 8 children of rights-003 and 1 child of rights-008

- [ ] **Step 3: Commit**

```bash
git add db/seeds.rb
git commit -m "chore(seed): load depends_on field from checklist JSON"
```

---

### Task 5: PdfAnalysisService — filter items by property type for LLM

**Files:**
- Modify: `app/services/pdf_analysis_service.rb`
- Modify: `test/services/inspection/pdf_prompt_builder_test.rb`

- [ ] **Step 1: Write failing test**

Add to `test/services/inspection/pdf_prompt_builder_test.rb`:

```ruby
test "applicable_for_type scope excludes items not matching property type" do
  commercial_only = InspectionItem.find_by(code: "property-003")
  skip "property-003 not seeded" unless commercial_only

  items = InspectionItem.applicable_for_type("아파트").ordered
  refute_includes items.map(&:code), "property-003"
end
```

- [ ] **Step 2: Run test to verify it passes** (scope already implemented in Task 2)

Run: `bin/rails test test/services/inspection/pdf_prompt_builder_test.rb`
Expected: All pass

- [ ] **Step 3: Update PdfAnalysisService to filter items**

In `app/services/pdf_analysis_service.rb`, update the `call_with_llm` method.

Find:
```ruby
    items = InspectionItem.ordered
    prompts = Inspection::PdfPromptBuilder.call(items: items)
```

Replace with:
```ruby
    items = if @property&.property_type.present?
      InspectionItem.applicable_for_type(@property.property_type).ordered
    else
      InspectionItem.ordered
    end
    prompts = Inspection::PdfPromptBuilder.call(items: items)
```

- [ ] **Step 4: Run full test suite**

Run: `bin/rails test`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add app/services/pdf_analysis_service.rb test/services/inspection/pdf_prompt_builder_test.rb
git commit -m "feat(llm): filter checklist items by property type in LLM prompt"
```

---

### Task 6: TabsController — filter displayed results

**Files:**
- Modify: `app/controllers/inspections/tabs_controller.rb`

- [ ] **Step 1: Update `edit` action to load all results and filter**

In `app/controllers/inspections/tabs_controller.rb`, replace the `edit` method body (lines 5-16):

Find:
```ruby
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
```

Replace with:
```ruby
    def edit
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @tab_key = params[:tab_key]
      return head(:not_found) unless VALID_TABS.include?(@tab_key)

      all_results = @property.inspection_results
        .where(user: current_user)
        .includes(:inspection_item)
      answered_context = all_results.index_by { |r| r.inspection_item.code }

      property_type = @property.property_type

      @results = all_results
        .select { |r| r.inspection_item.tab == @tab_key }
        .select { |r| r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context) }
        .sort_by { |r| r.inspection_item.tab_position }
    end
```

- [ ] **Step 2: Also update the `update` action stats query**

In `app/controllers/inspections/tabs_controller.rb`, update the `unanswered_count` calculation in the `update` method. Find:

```ruby
      tab_results = @property.inspection_results
        .joins(:inspection_item)
        .where(inspection_items: { tab: InspectionItem.tabs[@tab_key] }, user: current_user)
      unanswered_count = tab_results.where(has_risk: nil).count
```

Replace with:
```ruby
      all_results_for_count = @property.inspection_results
        .where(user: current_user)
        .includes(:inspection_item)
      answered_context = all_results_for_count.index_by { |r| r.inspection_item.code }
      property_type = @property.property_type

      visible_tab_results = all_results_for_count
        .select { |r| r.inspection_item.tab == @tab_key }
        .select { |r| r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context) }
      unanswered_count = visible_tab_results.count { |r| r.has_risk.nil? }
```

- [ ] **Step 3: Run full test suite**

Run: `bin/rails test`
Expected: All pass

- [ ] **Step 4: Commit**

```bash
git add app/controllers/inspections/tabs_controller.rb
git commit -m "feat(controller): filter checklist display by property type and depends_on"
```

---

### Task 7: InspectionTabsComponent — filter tab stats

**Files:**
- Modify: `app/components/inspection_tabs_component.rb`

- [ ] **Step 1: Replace `load_tab_stats` with filtered version**

In `app/components/inspection_tabs_component.rb`, replace the `load_tab_stats` method (lines 34-51):

Find:
```ruby
  def load_tab_stats
    results = @property.inspection_results
      .joins(:inspection_item)
      .where(user: @user)
      .group("inspection_items.tab")
      .select(
        "inspection_items.tab",
        "COUNT(*) AS total_count",
        "COUNT(CASE WHEN inspection_results.has_risk IS NOT NULL THEN 1 END) AS checked_count"
      )

    tab_int_to_key = InspectionItem.tabs.invert
    results.each_with_object({}) do |row, hash|
      key = tab_int_to_key[row.tab.to_i]
      next unless key
      hash[key] = { checked: row.checked_count.to_i, total: row.total_count.to_i }
    end
  end
```

Replace with:
```ruby
  def load_tab_stats
    all_results = @property.inspection_results
      .where(user: @user)
      .includes(:inspection_item)
    answered_context = all_results.index_by { |r| r.inspection_item.code }
    property_type = @property.property_type

    visible = all_results.select do |r|
      r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context)
    end

    visible.group_by { |r| r.inspection_item.tab }.each_with_object({}) do |(tab_key, results_in_tab), hash|
      hash[tab_key] = {
        checked: results_in_tab.count { |r| !r.has_risk.nil? },
        total: results_in_tab.size
      }
    end
  end
```

- [ ] **Step 2: Run full test suite**

Run: `bin/rails test`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add app/components/inspection_tabs_component.rb
git commit -m "feat(component): filter tab stats by property type and depends_on"
```

---

### Task 8: InspectionRatingService — filter grade calculation

**Files:**
- Modify: `app/services/inspection_rating_service.rb`

- [ ] **Step 1: Update `call` method to filter by visibility**

In `app/services/inspection_rating_service.rb`, replace the `call` method (lines 13-32):

Find:
```ruby
  def call
    results = @property.inspection_results.where(user: @user)
    answered = results.where.not(has_risk: nil)

    return :incomplete if answered.empty?

    risk_results = answered.where(has_risk: true)

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
```

Replace with:
```ruby
  def call
    all_results = @property.inspection_results.where(user: @user).includes(:inspection_item)
    answered_context = all_results.index_by { |r| r.inspection_item.code }
    property_type = @property.property_type

    visible = all_results.select do |r|
      r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context)
    end

    answered = visible.select { |r| !r.has_risk.nil? }
    return :incomplete if answered.empty?

    risk_results = answered.select { |r| r.has_risk }

    rating = if risk_results.any? { |r| r.resolvable == false }
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
```

- [ ] **Step 2: Update `tab_rating` method similarly**

Find:
```ruby
  def tab_rating(tab_key)
    tab_int = InspectionItem.tabs[tab_key]
    results = @property.inspection_results
      .joins(:inspection_item)
      .where(inspection_items: { tab: tab_int }, user: @user)

    return nil if results.empty?

    answered = results.where.not(has_risk: nil)
    return :incomplete if answered.empty?

    risk_results = answered.where(has_risk: true)

    if risk_results.exists?(resolvable: false)
      :danger
    elsif risk_results.any?
      :caution
    else
      :safe
    end
  end
```

Replace with:
```ruby
  def tab_rating(tab_key)
    visible = visible_results.select { |r| r.inspection_item.tab == tab_key }
    return nil if visible.empty?

    answered = visible.select { |r| !r.has_risk.nil? }
    return :incomplete if answered.empty?

    risk_results = answered.select { |r| r.has_risk }

    if risk_results.any? { |r| r.resolvable == false }
      :danger
    elsif risk_results.any?
      :caution
    else
      :safe
    end
  end
```

- [ ] **Step 3: Update `fully_evaluated?` and `tabs_evaluated_count`**

Find:
```ruby
  def fully_evaluated?
    results = @property.inspection_results.where(user: @user)
    results.any? && results.where(has_risk: nil).none?
  end
```

Replace with:
```ruby
  def fully_evaluated?
    visible_results.any? && visible_results.all? { |r| !r.has_risk.nil? }
  end
```

- [ ] **Step 4: Add memoized `visible_results` private method**

Add at the bottom of the private section (or create one if needed), before the closing `end`:

```ruby
  private

  def visible_results
    @visible_results ||= begin
      all_results = @property.inspection_results.where(user: @user).includes(:inspection_item)
      answered_context = all_results.index_by { |r| r.inspection_item.code }
      property_type = @property.property_type

      all_results.select do |r|
        r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context)
      end
    end
  end
```

- [ ] **Step 5: Run full test suite**

Run: `bin/rails test`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add app/services/inspection_rating_service.rb
git commit -m "feat(rating): filter grade calculation by property type and depends_on"
```

---

### Task 9: Cleanup and verification

**Files:**
- Delete: `scripts/merge_checklist_items.py` (one-time script)

- [ ] **Step 1: Delete the one-time merge script**

Run: `rm scripts/merge_checklist_items.py`

- [ ] **Step 2: Run full test suite**

Run: `bin/rails test`
Expected: All pass, no failures

- [ ] **Step 3: Verify seed data counts**

Run: `bin/rails runner "puts 'Total: ' + InspectionItem.count.to_s; puts 'With depends_on: ' + InspectionItem.where.not(depends_on: nil).count.to_s; puts 'With applicable_types: ' + InspectionItem.where.not(applicable_types: nil).count.to_s"`
Expected:
```
Total: 81
With depends_on: 9
With applicable_types: 29
```

- [ ] **Step 4: Verify filtering works for apartment**

Run: `bin/rails runner "apt_count = InspectionItem.applicable_for_type('아파트').count; puts \"Apartment visible: #{apt_count}/#{InspectionItem.count}\"; comm_count = InspectionItem.applicable_for_type('상가').count; puts \"Commercial visible: #{comm_count}/#{InspectionItem.count}\""`
Expected: Apartment visible count < 81 (non-apartment items filtered), Commercial visible count < 81 (non-commercial items filtered)

- [ ] **Step 5: Commit cleanup**

```bash
git add -A
git commit -m "chore: remove one-time merge script, verify filtering"
```
