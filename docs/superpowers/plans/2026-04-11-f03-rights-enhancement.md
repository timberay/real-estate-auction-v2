# F03 Rights Analysis Enhancement — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enhance the F03 rights analysis pipeline with hybrid LLM+Ruby validation — Ruby recalculates opposing power (대항력) and priority repayment rights (우선변제권) from LLM-extracted facts, adds HUG opportunity detection, source document review tracking, and a rights timeline visualization.

**Architecture:** LLM extracts raw facts (tenants, rights, dates) into `llm_raw`. A new `Inspection::RightsValidator` service recalculates opposing power, priority repayment, effective dates, and amounts in Ruby and stores results in `calculated`. Discrepancies between LLM and Ruby are tracked. Downstream components read from `calculated` with backward-compatible fallbacks.

**Tech Stack:** Rails 8.1, Minitest, ViewComponent, Stimulus, Turbo, SQLite

---

## File Map

### Files to Create

| File | Responsibility |
|------|---------------|
| `app/services/inspection/rights_validator.rb` | Ruby recalculation of opposing power, priority repayment, amounts, discrepancies |
| `test/services/inspection/rights_validator_test.rb` | Unit tests for all RightsValidator logic |
| `app/components/rights_timeline_component.rb` | Pure HTML/CSS horizontal timeline ViewComponent |
| `app/components/rights_timeline_component.html.erb` | Timeline template with base right marker and tenant display |
| `test/components/rights_timeline_component_test.rb` | Component rendering tests |
| `app/javascript/controllers/source_doc_review_controller.js` | Stimulus controller for source doc review PATCH + navigation confirm |
| `app/controllers/inspections/source_doc_reviews_controller.rb` | PATCH endpoint to mark source_doc_reviewed = true |

### Files to Modify

| File | Responsibility |
|------|---------------|
| `test/fixtures/files/ai_inspection_response.json` | Add `confirmed_date` to tenants, add `opportunity_type`/`opportunity_reason` |
| `app/services/inspection/pdf_prompt_builder.rb` | Add `confirmed_date` field and HUG opportunity detection to LLM prompt |
| `test/services/inspection/pdf_prompt_builder_test.rb` | Test `confirmed_date` and HUG prompt presence |
| `app/models/rights_analysis_report.rb` | Add `effective_tenants` and `effective_rights_timeline` backward-compat helpers |
| `app/services/pdf_analysis_service.rb` | Refactor `create_or_update_report` to use RightsValidator and new report_data structure |
| `test/services/pdf_analysis_service_test.rb` | Update tests for new report_data structure (llm_raw/calculated/discrepancies) |
| `app/components/source_doc_viewer_component.rb` | Read tenants/timeline from `calculated` namespace via model helpers |
| `test/components/source_doc_viewer_component_test.rb` | Update fixture data for new structure |
| `app/components/source_doc_viewer_component.html.erb` | Add source-doc-review controller, update data source |
| `app/components/registry_timeline_component.rb` | Read from `llm_raw` namespace via model helpers |
| `app/components/registry_timeline_component.html.erb` | Read `opposing_power` (not `has_opposing_power`) from calculated tenants |
| `test/components/registry_timeline_component_test.rb` | Update fixture data for new structure |
| `app/components/dividend_simulator_component.rb` | Read from `calculated` namespace via model helpers |
| `app/controllers/inspections/dividends_controller.rb` | Read from `calculated` namespace |
| `app/components/rights_report_section_component.html.erb` | Add HUG opportunity label and discrepancy warning |
| `config/routes.rb` | Add `source_doc_review` route |

---

## Task 1: Update Mock Fixture with confirmed_date and HUG Opportunity

**Files:**
- Modify: `test/fixtures/files/ai_inspection_response.json`

This is a prerequisite — every subsequent test relies on the mock adapter returning `confirmed_date` and opportunity data.

- [ ] **Step 1: Update the fixture file**

Replace the `tenants` and opportunity fields in `test/fixtures/files/ai_inspection_response.json`:

```json
"tenants": [
  {
    "name": "김○○",
    "deposit": 50000000,
    "move_in_date": "2023-06-01",
    "confirmed_date": "2023-06-15",
    "opposing_power": true,
    "priority_rank": 1
  },
  {
    "name": "박○○",
    "deposit": 30000000,
    "move_in_date": "2024-05-01",
    "confirmed_date": "2024-05-10",
    "opposing_power": false,
    "priority_rank": 3
  }
],
```

Also change:
```json
"opportunity_type": "hug_waiver",
"opportunity_reason": "HUG(주택도시보증공사) 전세보증금반환채권이 설정되어 있으나, 배당요구종기일까지 권리신고를 하지 않아 낙찰자에게 인수되지 않습니다.",
```

- [ ] **Step 2: Run existing tests to verify fixture change is backward-compatible**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb`
Expected: All tests pass (existing code ignores `confirmed_date` and reads `opportunity_type` already)

- [ ] **Step 3: Commit**

```bash
git add test/fixtures/files/ai_inspection_response.json
git commit -m "test: add confirmed_date and hug_waiver to mock fixture"
```

---

## Task 2: Create Inspection::RightsValidator Service (TDD)

**Files:**
- Create: `app/services/inspection/rights_validator.rb`
- Create: `test/services/inspection/rights_validator_test.rb`

The core business logic — pure calculation, no DB or IO.

- [ ] **Step 1: Write the failing test file**

Create `test/services/inspection/rights_validator_test.rb`:

```ruby
require "test_helper"

class Inspection::RightsValidatorTest < ActiveSupport::TestCase
  test "tenant with move_in_date before base_right_date has opposing power" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )

    tenant = result.validated_tenants.first
    assert_equal true, tenant["opposing_power"]
  end

  test "tenant with move_in_date on or after base_right_date has no opposing power" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "박○○", "deposit" => 30_000_000, "move_in_date" => "2024-01-15",
          "confirmed_date" => "2024-01-20", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )

    tenant = result.validated_tenants.first
    assert_equal false, tenant["opposing_power"]
  end

  test "priority repayment is independent of opposing power" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "박○○", "deposit" => 30_000_000, "move_in_date" => "2024-05-01",
          "confirmed_date" => "2024-05-10", "opposing_power" => false, "priority_rank" => 3 }
      ],
      rights_timeline: []
    )

    tenant = result.validated_tenants.first
    assert_equal false, tenant["opposing_power"]
    assert_equal true, tenant["has_priority_repayment"]
  end

  test "no priority repayment when confirmed_date is nil" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "최○○", "deposit" => 20_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => nil, "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )

    tenant = result.validated_tenants.first
    assert_equal true, tenant["opposing_power"]
    assert_equal false, tenant["has_priority_repayment"]
    assert_nil tenant["effective_date"]
    assert_nil tenant["priority_rank"]
  end

  test "effective_date uses max of move_in_date+1 and confirmed_date" do
    # confirmed_date (Jan 1) is before move_in_date+1 (Jan 6) → effective = Jan 6
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-06-01"),
      tenants: [
        { "name" => "이○○", "deposit" => 40_000_000, "move_in_date" => "2024-01-05",
          "confirmed_date" => "2024-01-01", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )

    tenant = result.validated_tenants.first
    assert_equal "2024-01-06", tenant["effective_date"]
  end

  test "effective_date uses confirmed_date when it is later" do
    # move_in_date+1 (Jun 2) is before confirmed_date (Jun 15) → effective = Jun 15
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2025-01-01"),
      tenants: [
        { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )

    tenant = result.validated_tenants.first
    assert_equal "2023-06-15", tenant["effective_date"]
  end

  test "priority_rank sorted by effective_date ascending" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2025-01-01"),
      tenants: [
        { "name" => "A", "deposit" => 10_000_000, "move_in_date" => "2024-06-01",
          "confirmed_date" => "2024-06-10", "opposing_power" => true, "priority_rank" => 1 },
        { "name" => "B", "deposit" => 20_000_000, "move_in_date" => "2024-03-01",
          "confirmed_date" => "2024-03-05", "opposing_power" => true, "priority_rank" => 2 }
      ],
      rights_timeline: []
    )

    tenants = result.validated_tenants
    assert_equal "B", tenants.find { |t| t["priority_rank"] == 1 }["name"]
    assert_equal "A", tenants.find { |t| t["priority_rank"] == 2 }["name"]
  end

  test "assumed_amount sums non-extinguished rights" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [],
      rights_timeline: [
        { "date" => "2024-01-15", "type" => "근저당권", "holder" => "○○은행", "amount" => 200_000_000, "extinguished_on_sale" => true },
        { "date" => "2023-01-01", "type" => "전세권", "holder" => "정○○", "amount" => 50_000_000, "extinguished_on_sale" => false }
      ]
    )

    assert_equal 50_000_000, result.validated_amounts["assumed_amount"]
  end

  test "total_risk_amount includes opposing tenant deposits" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: [
        { "date" => "2024-01-15", "type" => "근저당권", "holder" => "○○은행", "amount" => 200_000_000, "extinguished_on_sale" => true }
      ]
    )

    assert_equal 0, result.validated_amounts["assumed_amount"]
    assert_equal 50_000_000, result.validated_amounts["opposing_deposits"]
    assert_equal 50_000_000, result.validated_amounts["total_risk_amount"]
  end

  test "detects discrepancy when LLM and Ruby disagree on opposing_power" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "박○○", "deposit" => 30_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => false, "priority_rank" => 3 }
      ],
      rights_timeline: []
    )

    assert_equal 1, result.discrepancies.size
    d = result.discrepancies.first
    assert_equal "박○○", d["tenant_name"]
    assert_equal "opposing_power", d["field"]
    assert_equal false, d["llm_value"]
    assert_equal true, d["ruby_value"]
  end

  test "no discrepancies when LLM and Ruby agree" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )

    assert_empty result.discrepancies
  end

  test "handles empty tenants and rights" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [],
      rights_timeline: []
    )

    assert_empty result.validated_tenants
    assert_equal 0, result.validated_amounts["assumed_amount"]
    assert_equal 0, result.validated_amounts["opposing_deposits"]
    assert_equal 0, result.validated_amounts["total_risk_amount"]
    assert_empty result.discrepancies
  end

  test "handles nil base_right_date gracefully" do
    result = Inspection::RightsValidator.call(
      base_right_date: nil,
      tenants: [
        { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )

    tenant = result.validated_tenants.first
    assert_equal false, tenant["opposing_power"]
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/services/inspection/rights_validator_test.rb`
Expected: FAIL — `Inspection::RightsValidator` not defined

- [ ] **Step 3: Implement RightsValidator**

Create `app/services/inspection/rights_validator.rb`:

```ruby
module Inspection
  class RightsValidator
    Result = Struct.new(:validated_tenants, :validated_amounts, :discrepancies, keyword_init: true)

    def self.call(base_right_date:, tenants:, rights_timeline:)
      new(base_right_date:, tenants:, rights_timeline:).call
    end

    def initialize(base_right_date:, tenants:, rights_timeline:)
      @base_right_date = base_right_date.is_a?(String) ? Date.parse(base_right_date) : base_right_date
      @tenants = tenants || []
      @rights_timeline = rights_timeline || []
    end

    def call
      validated = @tenants.map { |t| validate_tenant(t) }
      discrepancies = detect_discrepancies(@tenants, validated)
      assign_priority_ranks!(validated)

      Result.new(
        validated_tenants: validated,
        validated_amounts: calculate_amounts(validated),
        discrepancies: discrepancies
      )
    end

    private

    def validate_tenant(tenant)
      move_in = parse_date(tenant["move_in_date"])
      confirmed = parse_date(tenant["confirmed_date"])

      opposing = if @base_right_date && move_in
        move_in < @base_right_date
      else
        false
      end

      has_priority = move_in.present? && confirmed.present?
      eff_date = has_priority ? [ move_in + 1.day, confirmed ].max : nil

      {
        "name" => tenant["name"],
        "deposit" => tenant["deposit"],
        "move_in_date" => tenant["move_in_date"],
        "confirmed_date" => tenant["confirmed_date"],
        "opposing_power" => opposing,
        "has_priority_repayment" => has_priority,
        "effective_date" => eff_date&.to_s,
        "priority_rank" => nil
      }
    end

    def assign_priority_ranks!(tenants)
      ranked = tenants
        .select { |t| t["has_priority_repayment"] }
        .sort_by { |t| t["effective_date"] }

      ranked.each_with_index { |t, i| t["priority_rank"] = i + 1 }
    end

    def calculate_amounts(validated_tenants)
      assumed = @rights_timeline
        .reject { |r| r["extinguished_on_sale"] }
        .sum { |r| r["amount"].to_i }

      opposing_deposits = validated_tenants
        .select { |t| t["opposing_power"] }
        .sum { |t| t["deposit"].to_i }

      {
        "assumed_amount" => assumed,
        "opposing_deposits" => opposing_deposits,
        "total_risk_amount" => assumed + opposing_deposits
      }
    end

    def detect_discrepancies(originals, validated)
      originals.each_with_index.filter_map do |original, idx|
        llm_val = original["opposing_power"]
        ruby_val = validated[idx]["opposing_power"]

        next if llm_val == ruby_val

        move_in = original["move_in_date"]
        {
          "tenant_name" => original["name"],
          "field" => "opposing_power",
          "llm_value" => llm_val,
          "ruby_value" => ruby_val,
          "reason" => "move_in_date(#{move_in}) #{ruby_val ? '<' : '>='} base_right_date(#{@base_right_date})"
        }
      end
    end

    def parse_date(str)
      return nil if str.blank?
      Date.parse(str)
    rescue Date::Error
      nil
    end
  end
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bin/rails test test/services/inspection/rights_validator_test.rb`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection/rights_validator.rb test/services/inspection/rights_validator_test.rb
git commit -m "feat: add Inspection::RightsValidator for hybrid LLM+Ruby rights validation"
```

---

## Task 3: Add Backward-Compatibility Helpers to RightsAnalysisReport Model

**Files:**
- Modify: `app/models/rights_analysis_report.rb`

Add helper methods so all components can migrate to the new data structure while still working with old data.

- [ ] **Step 1: Add helper methods**

Add to `app/models/rights_analysis_report.rb` after the `validates` lines:

```ruby
  def effective_tenants
    report_data&.dig("calculated", "tenants") || report_data&.dig("tenants") || []
  end

  def effective_rights_timeline
    report_data&.dig("llm_raw", "rights_timeline") || report_data&.dig("rights_timeline") || []
  end

  def discrepancies
    report_data&.dig("discrepancies") || []
  end
```

- [ ] **Step 2: Run full test suite to verify no regressions**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add app/models/rights_analysis_report.rb
git commit -m "feat: add backward-compatible data helpers to RightsAnalysisReport"
```

---

## Task 4: Update PdfPromptBuilder with confirmed_date and HUG Detection

**Files:**
- Modify: `app/services/inspection/pdf_prompt_builder.rb`
- Modify: `test/services/inspection/pdf_prompt_builder_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/services/inspection/pdf_prompt_builder_test.rb`:

```ruby
  test "includes confirmed_date field in tenant schema" do
    items = InspectionItem.ordered.limit(1)
    result = Inspection::PdfPromptBuilder.call(items: items)

    assert result[:system].include?("confirmed_date")
  end

  test "includes HUG opportunity detection instructions" do
    items = InspectionItem.ordered.limit(1)
    result = Inspection::PdfPromptBuilder.call(items: items)

    assert result[:system].include?("주택도시보증공사")
    assert result[:system].include?("hug_waiver")
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/inspection/pdf_prompt_builder_test.rb`
Expected: 2 new tests FAIL — `confirmed_date` and `주택도시보증공사` not in prompt

- [ ] **Step 3: Update the SYSTEM_PROMPT**

In `app/services/inspection/pdf_prompt_builder.rb`, replace the tenant line (line 35):

```
      - tenants: 임차인 배열. 각 항목은 { name, deposit(원), move_in_date(YYYY-MM-DD), opposing_power(boolean), priority_rank(정수) }
```

with:

```
      - tenants: 임차인 배열. 각 항목은 { name, deposit(원), move_in_date(YYYY-MM-DD), confirmed_date(YYYY-MM-DD 또는 null, 확정일자), opposing_power(boolean, 참고용 — 서버에서 재계산), priority_rank(정수, 참고용 — 서버에서 재계산) }
```

Replace the opportunity lines (lines 33-34):

```
      - opportunity_type: null | "gap_investment" | "occupancy"
      - opportunity_reason: 기회 요인 설명 (없으면 null)
```

with:

```
      - opportunity_type: null | "hug_waiver" | "gap_investment" | "occupancy"
        - "hug_waiver": HUG(주택도시보증공사) 전세보증금반환채권이 설정되어 있으나 권리신고를 포기하여 낙찰자 인수 부담이 없는 경우
        - "gap_investment": 시세 대비 저가 낙찰 가능성이 높은 갭투자 기회 물건
        - "occupancy": 점유 관련 기회 (임차인 자진퇴거 합의 등)
      - opportunity_reason: 기회 요인 상세 설명 (없으면 null). HUG 관련 시 등기부에서 확인한 근거를 명시하세요.
```

Also update the JSON example in the response format (line 66):

```
          "tenants": [{ "name": "...", "deposit": 0, "move_in_date": "YYYY-MM-DD", "opposing_power": true, "priority_rank": 1 }],
```

with:

```
          "tenants": [{ "name": "...", "deposit": 0, "move_in_date": "YYYY-MM-DD", "confirmed_date": "YYYY-MM-DD", "opposing_power": true, "priority_rank": 1 }],
```

And update the opportunity_type in the JSON example (line 64):

```
          "opportunity_type": null | "gap_investment" | "occupancy",
```

with:

```
          "opportunity_type": null | "hug_waiver" | "gap_investment" | "occupancy",
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/inspection/pdf_prompt_builder_test.rb`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection/pdf_prompt_builder.rb test/services/inspection/pdf_prompt_builder_test.rb
git commit -m "feat: add confirmed_date and HUG opportunity detection to LLM prompt"
```

---

## Task 5: Refactor PdfAnalysisService to Use RightsValidator

**Files:**
- Modify: `app/services/pdf_analysis_service.rb`
- Modify: `test/services/pdf_analysis_service_test.rb`

- [ ] **Step 1: Update existing tests for new report_data structure**

In `test/services/pdf_analysis_service_test.rb`, replace the test `"stores tenants and rights_timeline in report_data"` (lines 104-111):

```ruby
  test "stores report_data with llm_raw, calculated, and discrepancies" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    # llm_raw preserves LLM's original extraction
    assert_equal 2, report.report_data["llm_raw"]["tenants"].size
    assert_equal 3, report.report_data["llm_raw"]["rights_timeline"].size
    assert report.report_data["llm_raw"]["reasoning"].present?

    # calculated has Ruby-validated tenants
    assert_equal 2, report.report_data["calculated"]["tenants"].size

    # discrepancies is an array
    assert report.report_data["discrepancies"].is_a?(Array)
  end
```

Add new tests:

```ruby
  test "calculated tenants have opposing_power recalculated by Ruby" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    tenants = report.report_data["calculated"]["tenants"]
    kim = tenants.find { |t| t["name"] == "김○○" }
    park = tenants.find { |t| t["name"] == "박○○" }

    # 김○○: move_in 2023-06-01 < base_right 2024-01-15 → true
    assert_equal true, kim["opposing_power"]
    assert_equal true, kim["has_priority_repayment"]

    # 박○○: move_in 2024-05-01 >= base_right 2024-01-15 → false
    assert_equal false, park["opposing_power"]
    assert_equal true, park["has_priority_repayment"]
  end

  test "calculated amounts use Ruby values" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    amounts = report.report_data["calculated"]
    assert_equal 0, amounts["assumed_amount"]
    assert_equal 50_000_000, amounts["opposing_deposits"]
    assert_equal 50_000_000, amounts["total_risk_amount"]
  end

  test "DB columns match Ruby-calculated values" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_equal report.report_data.dig("calculated", "assumed_amount"), report.assumed_amount
    assert_equal report.report_data.dig("calculated", "total_risk_amount"), report.total_risk_amount
  end

  test "stores opportunity_type from LLM response" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_equal "hug_waiver", report.opportunity_type
    assert report.opportunity_reason.present?
  end

  test "effective_tenants helper returns calculated tenants" do
    result = PdfAnalysisService.call(property: @property, user: @user)
    report = RightsAnalysisReport.find_by(property: result.property, user: @user)

    assert_equal report.report_data["calculated"]["tenants"], report.effective_tenants
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb`
Expected: New tests FAIL — report_data still uses old flat structure

- [ ] **Step 3: Refactor create_or_update_report**

Replace the `create_or_update_report` method in `app/services/pdf_analysis_service.rb` (lines 94-138):

```ruby
  def create_or_update_report(property, response)
    report = RightsAnalysisReport.find_or_initialize_by(user: @user, property: property)
    rights_data = response["rights_analysis"]

    if rights_data.blank?
      report.update!(
        analyzed_at: Time.current,
        verdict_summary: nil,
        report_data: { "analysis_status" => "extraction_failed", "failed_at" => Time.current.iso8601 }
      )
      return
    end

    rights_timeline = rights_data["rights_timeline"] || []
    tenants = rights_data["tenants"] || []

    validation = Inspection::RightsValidator.call(
      base_right_date: rights_data["base_right_date"],
      tenants: tenants,
      rights_timeline: rights_timeline
    )

    report.update!(
      analyzed_at: Time.current,
      verdict: rights_data["verdict"],
      verdict_summary: rights_data["verdict_summary"],
      base_right_type: rights_data["base_right_type"],
      base_right_holder: rights_data["base_right_holder"],
      base_right_date: rights_data["base_right_date"],
      assumed_amount: validation.validated_amounts["assumed_amount"],
      total_risk_amount: validation.validated_amounts["total_risk_amount"],
      opportunity_type: rights_data["opportunity_type"],
      opportunity_reason: rights_data["opportunity_reason"],
      report_data: {
        "llm_raw" => {
          "tenants" => tenants,
          "rights_timeline" => rights_timeline,
          "reasoning" => rights_data["reasoning"],
          "checklist_references" => rights_data["checklist_references"]
        },
        "calculated" => {
          "tenants" => validation.validated_tenants,
          "assumed_amount" => validation.validated_amounts["assumed_amount"],
          "opposing_deposits" => validation.validated_amounts["opposing_deposits"],
          "total_risk_amount" => validation.validated_amounts["total_risk_amount"]
        },
        "discrepancies" => validation.discrepancies
      }
    )
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/pdf_analysis_service.rb test/services/pdf_analysis_service_test.rb
git commit -m "feat: integrate RightsValidator into PdfAnalysisService with llm_raw/calculated split"
```

---

## Task 6: Update SourceDocViewerComponent for New Data Structure

**Files:**
- Modify: `app/components/source_doc_viewer_component.rb`
- Modify: `test/components/source_doc_viewer_component_test.rb`

- [ ] **Step 1: Update test for new data structure**

Add to `test/components/source_doc_viewer_component_test.rb`:

```ruby
  test "reads tenants from calculated namespace" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => { "tenants" => [], "rights_timeline" => [] },
      "calculated" => {
        "tenants" => [
          { "name" => "김○○", "deposit" => 50_000_000, "opposing_power" => true }
        ]
      },
      "discrepancies" => []
    }
    render_inline(SourceDocViewerComponent.new(report: report))
    assert_text "대항력 있음: 1명"
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/source_doc_viewer_component_test.rb`
Expected: New test FAILS — component still reads from top-level

- [ ] **Step 3: Update component to use model helpers**

Replace `tenants` and `rights_timeline` methods in `app/components/source_doc_viewer_component.rb`:

```ruby
  def tenants
    @report&.effective_tenants || []
  end

  def rights_timeline
    @report&.effective_rights_timeline || []
  end
```

Remove the `parse_report_data` method call from `initialize` and the `@report_data` instance variable. Update `extraction_failed?` and `has_data?`:

```ruby
class SourceDocViewerComponent < ViewComponent::Base
  def initialize(report:)
    @report = report
  end

  private

  def tenants
    @report&.effective_tenants || []
  end

  def tenants_with_opposing_power
    tenants.count { |t| t["opposing_power"] }
  end

  def rights_timeline
    @report&.effective_rights_timeline || []
  end

  def extraction_failed?
    @report&.report_data&.dig("analysis_status") == "extraction_failed"
  end

  def has_data?
    @report.present? && !extraction_failed?
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/components/source_doc_viewer_component_test.rb`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/components/source_doc_viewer_component.rb test/components/source_doc_viewer_component_test.rb
git commit -m "refactor: update SourceDocViewerComponent to use model helpers for new data structure"
```

---

## Task 7: Update RegistryTimelineComponent for New Data Structure

**Files:**
- Modify: `app/components/registry_timeline_component.rb`
- Modify: `app/components/registry_timeline_component.html.erb`
- Modify: `test/components/registry_timeline_component_test.rb`

- [ ] **Step 1: Update test for new data structure**

Replace `test/components/registry_timeline_component_test.rb`:

```ruby
require "test_helper"

class RegistryTimelineComponentTest < ViewComponent::TestCase
  test "renders timeline entries from llm_raw" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => {
        "rights_timeline" => [
          { "date" => "2024-01-15", "type" => "근저당", "holder" => "국민은행", "amount" => 200_000_000, "extinguished_on_sale" => true }
        ]
      },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }
    render_inline(RegistryTimelineComponent.new(report: report))
    assert_text "국민은행"
    assert_text "근저당"
  end

  test "renders tenants from calculated namespace" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => { "rights_timeline" => [] },
      "calculated" => {
        "tenants" => [
          { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
            "confirmed_date" => "2023-06-15", "opposing_power" => true }
        ]
      },
      "discrepancies" => []
    }
    render_inline(RegistryTimelineComponent.new(report: report))
    assert_text "김○○"
    assert_text "대항력 있음"
  end

  test "renders empty state when no data" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "llm_raw" => { "rights_timeline" => [] }, "calculated" => { "tenants" => [] }, "discrepancies" => [] }
    render_inline(RegistryTimelineComponent.new(report: report))
    assert_text "등기부"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/registry_timeline_component_test.rb`
Expected: FAIL — component reads from `registry_timeline` (wrong key) and top-level `tenants`

- [ ] **Step 3: Update component to use model helpers**

Replace `app/components/registry_timeline_component.rb`:

```ruby
class RegistryTimelineComponent < ViewComponent::Base
  def initialize(report:)
    @report = report
    @timeline = report.effective_rights_timeline
    @tenants = report.effective_tenants
    @checklist_refs = report.report_data&.dig("llm_raw", "checklist_references") ||
                      report.report_data&.dig("checklist_references") || []
  end

  private

  def base_right_date
    @report.base_right_date
  end

  def format_amount(amount)
    return "—" if amount.nil?
    amount.to_fs(:delimited) + "원"
  end
end
```

- [ ] **Step 4: Update template to use `opposing_power` key**

In `app/components/registry_timeline_component.html.erb`, replace `has_opposing_power` with `opposing_power` on line 24:

```erb
        <% has_power = tenant["opposing_power"] %>
```

(This line may already reference `has_opposing_power` — change it to `opposing_power` to match the data structure.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/components/registry_timeline_component_test.rb`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add app/components/registry_timeline_component.rb app/components/registry_timeline_component.html.erb test/components/registry_timeline_component_test.rb
git commit -m "refactor: update RegistryTimelineComponent to use model helpers and new data structure"
```

---

## Task 8: Update DividendsController for New Data Structure

**Files:**
- Modify: `app/controllers/inspections/dividends_controller.rb`

- [ ] **Step 1: Update data reads to use calculated namespace**

In `app/controllers/inspections/dividends_controller.rb`, replace lines 35-37 in `calculate_distribution`:

```ruby
      data = parsed_report_data
      rights = data["rights_timeline"] || []
      tenants = data["tenants"] || []
```

with:

```ruby
      data = parsed_report_data
      rights = data.dig("llm_raw", "rights_timeline") || data["rights_timeline"] || []
      tenants = data.dig("calculated", "tenants") || data["tenants"] || []
```

- [ ] **Step 2: Run existing dividend tests**

Run: `bin/rails test test/controllers/inspections/dividends_controller_test.rb` (if exists) or `bin/rails test`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add app/controllers/inspections/dividends_controller.rb
git commit -m "refactor: update DividendsController to read from calculated/llm_raw namespaces"
```

---

## Task 9: Add HUG Opportunity Label and Discrepancy Warning to RightsReportSectionComponent

**Files:**
- Modify: `app/components/rights_report_section_component.html.erb`

- [ ] **Step 1: Update the template**

Replace `app/components/rights_report_section_component.html.erb`:

```erb
<% if @report %>
  <div class="space-y-4">
    <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">권리 분석 리포트</h3>

    <%# HUG Opportunity Label %>
    <% if @report.opportunity_type.present? %>
      <div class="rounded-lg bg-green-50 dark:bg-green-900/20 border border-green-300 dark:border-green-700 px-4 py-3">
        <div class="flex items-center gap-2">
          <span class="inline-flex items-center rounded-full bg-green-100 dark:bg-green-800/40 px-3 py-1 text-sm font-semibold text-green-800 dark:text-green-300">
            안전 기회물건
          </span>
          <span class="text-sm font-medium text-green-700 dark:text-green-400">
            <% case @report.opportunity_type %>
            <% when "hug_waiver" %>
              HUG 권리신고 포기
            <% when "gap_investment" %>
              갭투자 기회
            <% when "occupancy" %>
              점유 기회
            <% end %>
          </span>
        </div>
        <% if @report.opportunity_reason.present? %>
          <details class="mt-2">
            <summary class="text-sm text-green-600 dark:text-green-400 cursor-pointer">상세 사유 보기</summary>
            <p class="mt-1 text-sm text-green-700 dark:text-green-300"><%= @report.opportunity_reason %></p>
          </details>
        <% end %>
      </div>
    <% end %>

    <%# Discrepancy Warning %>
    <% if @report.discrepancies.any? %>
      <div class="rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-300 dark:border-amber-700 px-4 py-3">
        <p class="text-sm font-semibold text-amber-800 dark:text-amber-200 mb-2">AI 판단과 자동계산 결과가 다른 항목이 있습니다</p>
        <table class="w-full text-sm">
          <thead>
            <tr class="text-left text-amber-700 dark:text-amber-300">
              <th class="pr-4 pb-1">임차인</th>
              <th class="pr-4 pb-1">AI 판단</th>
              <th class="pr-4 pb-1">자동계산</th>
              <th class="pb-1">사유</th>
            </tr>
          </thead>
          <tbody>
            <% @report.discrepancies.each do |d| %>
              <tr class="text-amber-800 dark:text-amber-200">
                <td class="pr-4 py-0.5"><%= d["tenant_name"] %></td>
                <td class="pr-4 py-0.5"><%= d["llm_value"] ? "대항력 있음" : "대항력 없음" %></td>
                <td class="pr-4 py-0.5"><%= d["ruby_value"] ? "대항력 있음" : "대항력 없음" %></td>
                <td class="py-0.5 text-xs"><%= d["reason"] %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    <% end %>

    <%= render ReportSummaryComponent.new(report: @report, property: @property) %>
    <%= render RegistryTimelineComponent.new(report: @report) %>
    <%= render DividendSimulatorComponent.new(report: @report, property: @property) %>
    <%= render SourceDocViewerComponent.new(report: @report) %>
    <%= render LegalDisclaimerComponent.new %>
  </div>
<% end %>
```

- [ ] **Step 2: Run full test suite**

Run: `bin/rails test`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add app/components/rights_report_section_component.html.erb
git commit -m "feat: add HUG opportunity label and discrepancy warning to rights report"
```

---

## Task 10: Create RightsTimelineComponent

**Files:**
- Create: `app/components/rights_timeline_component.rb`
- Create: `app/components/rights_timeline_component.html.erb`
- Create: `test/components/rights_timeline_component_test.rb`

A pure HTML/CSS horizontal timeline showing rights chronologically with a base right marker.

- [ ] **Step 1: Write failing tests**

Create `test/components/rights_timeline_component_test.rb`:

```ruby
require "test_helper"

class RightsTimelineComponentTest < ViewComponent::TestCase
  test "renders rights sorted by date" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => {
        "rights_timeline" => [
          { "date" => "2024-08-10", "type" => "가압류", "holder" => "이○○", "amount" => 10_000_000, "extinguished_on_sale" => true },
          { "date" => "2024-01-15", "type" => "근저당권", "holder" => "○○은행", "amount" => 200_000_000, "extinguished_on_sale" => true }
        ]
      },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }

    render_inline(RightsTimelineComponent.new(report: report))

    # Both should render
    assert_text "○○은행"
    assert_text "이○○"
    assert_text "말소기준권리"
  end

  test "extinguished rights have strikethrough style" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => {
        "rights_timeline" => [
          { "date" => "2024-01-15", "type" => "근저당권", "holder" => "○○은행", "amount" => 200_000_000, "extinguished_on_sale" => true }
        ]
      },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }

    render_inline(RightsTimelineComponent.new(report: report))
    assert_selector "[data-status='extinguished']"
    assert_text "소멸"
  end

  test "assumed rights have danger style" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => {
        "rights_timeline" => [
          { "date" => "2023-01-01", "type" => "전세권", "holder" => "정○○", "amount" => 50_000_000, "extinguished_on_sale" => false }
        ]
      },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }

    render_inline(RightsTimelineComponent.new(report: report))
    assert_selector "[data-status='assumed']"
    assert_text "인수"
  end

  test "renders opposing-power tenants on timeline" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => { "rights_timeline" => [] },
      "calculated" => {
        "tenants" => [
          { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
            "opposing_power" => true, "has_priority_repayment" => true, "effective_date" => "2023-06-15" }
        ]
      },
      "discrepancies" => []
    }

    render_inline(RightsTimelineComponent.new(report: report))
    assert_text "김○○"
    assert_text "대항력"
  end

  test "renders empty state when no data" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => { "rights_timeline" => [] },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }

    render_inline(RightsTimelineComponent.new(report: report))
    assert_text "권리 설정 내역이 없습니다"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/rights_timeline_component_test.rb`
Expected: FAIL — `RightsTimelineComponent` not defined

- [ ] **Step 3: Create the component Ruby class**

Create `app/components/rights_timeline_component.rb`:

```ruby
class RightsTimelineComponent < ViewComponent::Base
  def initialize(report:)
    @report = report
    @rights = report.effective_rights_timeline.sort_by { |r| r["date"].to_s }
    @tenants = report.effective_tenants
  end

  private

  def base_right_date
    @report.base_right_date&.to_s
  end

  def all_entries
    entries = @rights.map do |right|
      {
        date: right["date"],
        type: right["type"],
        holder: right["holder"],
        amount: right["amount"],
        extinguished: right["extinguished_on_sale"],
        is_base: right["date"] == base_right_date,
        kind: :right
      }
    end

    @tenants.select { |t| t["opposing_power"] }.each do |tenant|
      entries << {
        date: tenant["move_in_date"],
        type: "임차인 전입",
        holder: tenant["name"],
        amount: tenant["deposit"],
        extinguished: false,
        is_base: false,
        kind: :tenant
      }
    end

    entries.sort_by { |e| e[:date].to_s }
  end

  def has_data?
    @rights.any? || @tenants.any?
  end

  def format_amount(amount)
    return "—" if amount.nil?
    amount.to_fs(:delimited) + "원"
  end
end
```

- [ ] **Step 4: Create the template**

Create `app/components/rights_timeline_component.html.erb`:

```erb
<div class="space-y-3">
  <h4 class="text-sm font-semibold text-slate-900 dark:text-slate-100">권리 타임라인</h4>

  <% if has_data? %>
    <div class="overflow-x-auto">
      <div class="relative min-w-[400px]">
        <%# Horizontal timeline bar %>
        <div class="absolute top-5 left-0 right-0 h-0.5 bg-slate-300 dark:bg-slate-600"></div>

        <div class="flex gap-4 pb-2">
          <% all_entries.each do |entry| %>
            <div class="relative flex-shrink-0 w-40 pt-8"
                 data-status="<%= entry[:extinguished] ? 'extinguished' : 'assumed' %>">
              <%# Timeline dot %>
              <div class="absolute top-3 left-1/2 -translate-x-1/2 w-3 h-3 rounded-full border-2 border-white dark:border-slate-900
                          <%= if entry[:is_base]
                                'bg-red-500 ring-2 ring-red-300'
                              elsif entry[:kind] == :tenant
                                'bg-blue-500'
                              elsif entry[:extinguished]
                                'bg-slate-400'
                              else
                                'bg-red-500'
                              end %>"></div>

              <%# Base right label %>
              <% if entry[:is_base] %>
                <div class="absolute -top-1 left-1/2 -translate-x-1/2 whitespace-nowrap">
                  <span class="text-xs font-bold text-red-600 dark:text-red-400 bg-red-50 dark:bg-red-900/30 px-1.5 py-0.5 rounded">말소기준권리</span>
                </div>
              <% end %>

              <%# Card %>
              <div class="rounded-lg border p-2.5 text-xs
                          <%= if entry[:kind] == :tenant
                                'border-blue-200 bg-blue-50 dark:border-blue-700 dark:bg-blue-900/20'
                              elsif entry[:extinguished]
                                'border-slate-200 bg-slate-50 dark:border-slate-700 dark:bg-slate-800/50'
                              else
                                'border-red-200 bg-red-50 dark:border-red-700 dark:bg-red-900/20'
                              end %>">
                <div class="text-slate-500 dark:text-slate-400"><%= entry[:date] %></div>
                <div class="font-semibold mt-0.5
                            <%= entry[:extinguished] ? 'text-slate-400 dark:text-slate-500 line-through' : 'text-slate-900 dark:text-slate-100' %>">
                  <%= entry[:type] %>
                </div>
                <div class="text-slate-600 dark:text-slate-300 mt-0.5"><%= entry[:holder] %></div>
                <div class="mt-1 font-medium
                            <%= if entry[:kind] == :tenant
                                  'text-blue-700 dark:text-blue-400'
                                elsif entry[:extinguished]
                                  'text-slate-400 dark:text-slate-500'
                                else
                                  'text-red-700 dark:text-red-400'
                                end %>">
                  <%= format_amount(entry[:amount]) %>
                </div>
                <div class="mt-1">
                  <% if entry[:kind] == :tenant %>
                    <span class="text-blue-600 dark:text-blue-400 font-medium">대항력 있음</span>
                  <% elsif entry[:extinguished] %>
                    <span class="text-slate-400 dark:text-slate-500">소멸</span>
                  <% else %>
                    <span class="text-red-600 dark:text-red-400 font-semibold">인수</span>
                  <% end %>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
  <% else %>
    <p class="text-sm text-slate-500 dark:text-slate-400">권리 설정 내역이 없습니다.</p>
  <% end %>
</div>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/components/rights_timeline_component_test.rb`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add app/components/rights_timeline_component.rb app/components/rights_timeline_component.html.erb test/components/rights_timeline_component_test.rb
git commit -m "feat: add RightsTimelineComponent with horizontal CSS timeline"
```

---

## Task 11: Add Source Document Review Tracking

**Files:**
- Create: `app/javascript/controllers/source_doc_review_controller.js`
- Modify: `app/components/source_doc_viewer_component.html.erb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Add the route**

In `config/routes.rb`, inside the `namespace :inspections` block (after the `resource :dividend` line), add:

```ruby
      resource :source_doc_review, only: [ :update ], controller: "source_doc_reviews"
```

- [ ] **Step 2: Create the controller**

Create `app/controllers/inspections/source_doc_reviews_controller.rb`:

```ruby
module Inspections
  class SourceDocReviewsController < ApplicationController
    def update
      property = Property.find(params[:property_id])
      report = RightsAnalysisReport.find_by!(property: property, user: current_user)
      report.update!(source_doc_reviewed: true, user_confirmed_at: Time.current)

      head :ok
    end
  end
end
```

- [ ] **Step 3: Create the Stimulus controller**

Create `app/javascript/controllers/source_doc_review_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    reviewed: { type: Boolean, default: false }
  }

  markReviewed() {
    if (this.reviewedValue) return

    this.reviewedValue = true
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
        "Content-Type": "application/json"
      }
    })
  }

  confirmNavigation(event) {
    if (this.reviewedValue) return

    if (!confirm("원본 서류(매각물건명세서, 등기부등본)를 확인하셨나요?")) {
      event.preventDefault()
    }
  }
}
```

- [ ] **Step 4: Update SourceDocViewerComponent template to use new controller**

In `app/components/source_doc_viewer_component.html.erb`, replace the outer `div` opening tag (line 1):

```erb
<div class="space-y-4" data-controller="source-doc-tracker">
```

with:

```erb
<div class="space-y-4"
     data-controller="source-doc-tracker source-doc-review"
     data-source-doc-review-url-value="<%= @review_url %>"
     data-source-doc-review-reviewed-value="<%= @source_doc_reviewed %>">
```

Update tab buttons (lines 14-19) to add the `markReviewed` action:

```erb
      <button class="px-4 py-2 text-sm font-medium border-b-2 border-blue-600 text-blue-600 dark:border-blue-400 dark:text-blue-400"
              data-source-doc-tracker-target="tab" data-action="click->source-doc-tracker#switchTab click->source-doc-review#markReviewed"
              data-doc-type="court_auction">매각물건명세서</button>
      <button class="px-4 py-2 text-sm font-medium border-b-2 border-transparent text-slate-500 dark:text-slate-400"
              data-source-doc-tracker-target="tab" data-action="click->source-doc-tracker#switchTab click->source-doc-review#markReviewed"
              data-doc-type="registry">등기부등본</button>
```

- [ ] **Step 5: Update SourceDocViewerComponent Ruby to pass review_url and reviewed state**

In `app/components/source_doc_viewer_component.rb`, update `initialize`:

```ruby
class SourceDocViewerComponent < ViewComponent::Base
  include ActionView::Helpers::UrlHelper

  def initialize(report:, property: nil)
    @report = report
    @property = property
    @source_doc_reviewed = report&.source_doc_reviewed || false
    @review_url = property ? Rails.application.routes.url_helpers.property_inspections_source_doc_review_path(property) : ""
  end
```

- [ ] **Step 6: Update callers to pass property**

In `app/components/rights_report_section_component.html.erb`, update the SourceDocViewerComponent render call:

```erb
    <%= render SourceDocViewerComponent.new(report: @report, property: @property) %>
```

- [ ] **Step 7: Run full test suite**

Run: `bin/rails test`
Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add app/javascript/controllers/source_doc_review_controller.js \
  app/controllers/inspections/source_doc_reviews_controller.rb \
  app/components/source_doc_viewer_component.rb \
  app/components/source_doc_viewer_component.html.erb \
  app/components/rights_report_section_component.html.erb \
  config/routes.rb
git commit -m "feat: add source document review tracking with Stimulus controller"
```

---

## Task 12: Update DividendSimulatorComponent for New Data Structure

**Files:**
- Modify: `app/components/dividend_simulator_component.rb`

- [ ] **Step 1: Update simulation data read**

In `app/components/dividend_simulator_component.rb`, update the `initialize` method (line 11):

```ruby
    @simulation = report.report_data&.dig("user_simulation") ||
                  report.report_data&.dig("calculated", "user_simulation") || {}
```

No other changes needed — the simulation namespace is already isolated.

- [ ] **Step 2: Run component tests**

Run: `bin/rails test test/components/dividend_simulator_component_test.rb`
Expected: All tests PASS

- [ ] **Step 3: Commit**

```bash
git add app/components/dividend_simulator_component.rb
git commit -m "refactor: update DividendSimulatorComponent for new report_data structure"
```

---

## Task 13: Full Integration Test

**Files:** None (verification only)

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: All tests PASS

- [ ] **Step 2: Run linter**

Run: `bin/rubocop`
Expected: No new offenses

- [ ] **Step 3: Run security checks**

Run: `bin/brakeman --quiet --no-pager`
Expected: No warnings

- [ ] **Step 4: Final commit if any linter fixes needed**

```bash
git add -A
git commit -m "chore: fix lint issues from F03 rights enhancement"
```
