# AI Inspection Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace keyword-based inspection with LLM-powered analysis that determines 22/29 checklist items from existing property data, with fallback to current rules on failure.

**Architecture:** `AiInspectionRunner` orchestrates four components: `PropertyDataAssembler` (data → text), `InspectionPromptBuilder` (text → prompt), `LlmAdapter` (prompt → JSON), `InspectionResultMapper` (JSON → DB). `PropertyInspectionService` tries AI first, falls back to existing `InspectionRunner` on error.

**Tech Stack:** Rails 8.1, Minitest, existing adapter pattern (base class + mock/real), InspectionResult model with source_type enum.

**Spec:** `docs/superpowers/specs/2026-04-10-ai-inspection-runner-design.md`

---

### Task 1: Add `ai` to InspectionResult source_type enum

**Files:**
- Modify: `app/models/inspection_result.rb:6`
- Test: `test/models/inspection_result_test.rb` (create)

- [ ] **Step 1: Write the failing test**

Create `test/models/inspection_result_test.rb`:

```ruby
require "test_helper"

class InspectionResultTest < ActiveSupport::TestCase
  test "source_type enum includes ai" do
    result = InspectionResult.new(source_type: :ai)
    assert result.ai?
    assert_equal 2, InspectionResult.source_types["ai"]
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec bin/rails test test/models/inspection_result_test.rb -v`
Expected: FAIL — `ArgumentError: 'ai' is not a valid source_type`

- [ ] **Step 3: Add ai enum value**

In `app/models/inspection_result.rb`, change line 6:

```ruby
enum :source_type, { auto: 0, manual: 1, ai: 2 }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec bin/rails test test/models/inspection_result_test.rb -v`
Expected: PASS

- [ ] **Step 5: Run full test suite to ensure no regressions**

Run: `bundle exec bin/rails test`
Expected: All existing tests pass

- [ ] **Step 6: Commit**

```bash
git add app/models/inspection_result.rb test/models/inspection_result_test.rb
git commit -m "feat: add ai source_type to InspectionResult enum"
```

---

### Task 2: Create LlmAdapter base class

**Files:**
- Create: `app/adapters/llm_adapter.rb`
- Test: `test/adapters/llm_adapter_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/adapters/llm_adapter_test.rb`:

```ruby
require "test_helper"

class LlmAdapterTest < ActiveSupport::TestCase
  test "base class raises NotImplementedError on analyze" do
    adapter = LlmAdapter.new
    assert_raises(NotImplementedError) do
      adapter.analyze(system: "test", prompt: "test")
    end
  end

  test ".for returns MockLlmAdapter when USE_MOCK is true" do
    ClimateControl.modify(USE_MOCK: "true") do
      adapter = LlmAdapter.for
      assert_instance_of MockLlmAdapter, adapter
    end
  end

  test ".for returns AnthropicLlmAdapter when USE_MOCK is not true" do
    ClimateControl.modify(USE_MOCK: "false") do
      adapter = LlmAdapter.for
      assert_instance_of AnthropicLlmAdapter, adapter
    end
  end

  test "sanitize_and_parse_json strips markdown code block wrapper" do
    adapter = LlmAdapter.new
    raw = "```json\n{\"results\": {}}\n```"
    parsed = adapter.send(:sanitize_and_parse_json, raw)
    assert_equal({}, parsed["results"])
  end

  test "sanitize_and_parse_json handles plain JSON" do
    adapter = LlmAdapter.new
    raw = '{"results": {}}'
    parsed = adapter.send(:sanitize_and_parse_json, raw)
    assert_equal({}, parsed["results"])
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec bin/rails test test/adapters/llm_adapter_test.rb -v`
Expected: FAIL — `NameError: uninitialized constant LlmAdapter`

- [ ] **Step 3: Check if climate_control gem exists, add if needed**

Run: `bundle exec ruby -e "require 'climate_control'" 2>&1 || echo "MISSING"`

If missing, use ENV stubbing instead. Replace ClimateControl in tests with:

```ruby
test ".for returns MockLlmAdapter when USE_MOCK is true" do
  original = ENV["USE_MOCK"]
  ENV["USE_MOCK"] = "true"
  adapter = LlmAdapter.for
  assert_instance_of MockLlmAdapter, adapter
ensure
  ENV["USE_MOCK"] = original
end
```

- [ ] **Step 4: Implement LlmAdapter base class**

Create `app/adapters/llm_adapter.rb`:

```ruby
class LlmAdapter
  def self.for
    if ENV["USE_MOCK"] == "true"
      MockLlmAdapter.new
    else
      AnthropicLlmAdapter.new
    end
  end

  def analyze(system:, prompt:)
    raise NotImplementedError, "#{self.class}#analyze must be implemented"
  end

  private

  # LLMs often wrap JSON in markdown code blocks (```json ... ```).
  # This strips that wrapper before parsing.
  def sanitize_and_parse_json(raw)
    cleaned = raw.strip
      .gsub(/\A```(?:json)?\s*\n?/, "")
      .gsub(/\n?```\s*\z/, "")
    JSON.parse(cleaned)
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec bin/rails test test/adapters/llm_adapter_test.rb -v`
Expected: FAIL — still needs MockLlmAdapter and AnthropicLlmAdapter (created in Tasks 3-4)

- [ ] **Step 6: Commit (partial — base class only)**

```bash
git add app/adapters/llm_adapter.rb test/adapters/llm_adapter_test.rb
git commit -m "feat: add LlmAdapter base class with factory method"
```

---

### Task 3: Create MockLlmAdapter

**Files:**
- Create: `app/adapters/mock_llm_adapter.rb`
- Create: `test/fixtures/files/ai_inspection_response.json`
- Test: `test/adapters/mock_llm_adapter_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/adapters/mock_llm_adapter_test.rb`:

```ruby
require "test_helper"

class MockLlmAdapterTest < ActiveSupport::TestCase
  test "analyze returns parsed JSON hash with results key" do
    adapter = MockLlmAdapter.new
    response = adapter.analyze(system: "ignored", prompt: "ignored")
    assert_kind_of Hash, response
    assert response.key?("results"), "Response must have 'results' key"
  end

  test "response contains rights-002 item with required fields" do
    adapter = MockLlmAdapter.new
    response = adapter.analyze(system: "ignored", prompt: "ignored")
    item = response["results"]["rights-002"]
    assert_not_nil item
    assert_includes [true, false, nil], item["has_risk"]
    assert_includes %w[high medium none], item["confidence"]
    assert item["reasoning"].present?
  end

  test "response contains all 29 rights_analysis items" do
    adapter = MockLlmAdapter.new
    response = adapter.analyze(system: "ignored", prompt: "ignored")
    rights_codes = InspectionItem.where(tab: :rights_analysis).pluck(:code)
    rights_codes.each do |code|
      assert response["results"].key?(code), "Missing item: #{code}"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec bin/rails test test/adapters/mock_llm_adapter_test.rb -v`
Expected: FAIL — `NameError: uninitialized constant MockLlmAdapter`

- [ ] **Step 3: Create fixture JSON**

Create `test/fixtures/files/ai_inspection_response.json` with a realistic mock response. This fixture simulates the `risky_villa` property (유치권 신고 있음, 임차권등기 인수):

```json
{
  "results": {
    "rights-002": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "매각물건명세서에 '을구 1번 주택임차권등기 — 배당에서 전액 변제받지 않으면 매수인이 인수'로 기재되어 있어 인수할 권리가 존재합니다."
    },
    "rights-001": {
      "has_risk": false,
      "confidence": "medium",
      "reasoning": "매각물건명세서에 가처분 관련 기재가 없으며, 임의경매 사건으로 소유권 분쟁 가능성이 낮습니다."
    },
    "rights-017": {
      "has_risk": null,
      "confidence": "none",
      "reasoning": "세금 압류 송달 일자 데이터가 없어 판단할 수 없습니다."
    },
    "rights-011": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "비고란에 '유치권 신고 있음'으로 기재되어 있습니다."
    },
    "rights-004": {
      "has_risk": false,
      "confidence": "medium",
      "reasoning": "매각물건명세서에 가등기 관련 기재가 없습니다."
    },
    "rights-021": {
      "has_risk": false,
      "confidence": "high",
      "reasoning": "전세사기 특별법 또는 우선매수권 관련 기재가 없습니다."
    },
    "rights-005": {
      "has_risk": false,
      "confidence": "medium",
      "reasoning": "무허가, 미등기 등의 기재가 없어 정상 건물로 추정됩니다."
    },
    "rights-007": {
      "has_risk": false,
      "confidence": "medium",
      "reasoning": "매각물건명세서에 예고등기 관련 기재가 없습니다."
    },
    "rights-003": {
      "has_risk": null,
      "confidence": "none",
      "reasoning": "현황조사서 데이터가 없어 임차인 거주 여부를 판단할 수 없습니다."
    },
    "rights-008": {
      "has_risk": false,
      "confidence": "medium",
      "reasoning": "매각물건명세서에 선순위 세금 압류 관련 기재가 없습니다."
    },
    "rights-009": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "임차권등기가 존재하며 HUG 대항력 포기 확약서에 대한 언급이 없습니다."
    },
    "rights-012": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "을구 1번 주택임차권등기가 존재하므로 선순위 임차권이 설정되어 있습니다."
    },
    "rights-006": {
      "has_risk": null,
      "confidence": "none",
      "reasoning": "배당요구 신청 여부를 확인할 수 있는 데이터가 없습니다."
    },
    "rights-013": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "을구 1번 주택임차권등기가 설정되어 있습니다."
    },
    "rights-010": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "'배당에서 전액 변제받지 않으면 매수인이 인수'라고 명시되어 미배당 보증금 발생 가능성이 있습니다."
    },
    "rights-022": {
      "has_risk": false,
      "confidence": "high",
      "reasoning": "질권 관련 기재가 없습니다."
    },
    "rights-014": {
      "has_risk": null,
      "confidence": "none",
      "reasoning": "임차인의 보증금, 확정일자, 배당요구 상세 정보가 없습니다."
    },
    "rights-023": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "임차권등기가 포함되어 있어 금전 채권만으로 구성되지 않았습니다."
    },
    "eviction-001": {
      "has_risk": false,
      "confidence": "medium",
      "reasoning": "감정평가서 또는 현황조사서에 화재, 누수, 크랙 등의 기재가 없습니다."
    },
    "manual-001": {
      "has_risk": false,
      "confidence": "high",
      "reasoning": "경기도 수원시 빌라 3층 물건으로 분묘기지권 성립 가능성이 없습니다."
    },
    "rights-015": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "임차권등기가 대항력을 가지고 있어 소멸되지 않습니다."
    },
    "eviction-005": {
      "has_risk": null,
      "confidence": "none",
      "reasoning": "미납 관리비 데이터가 없습니다."
    },
    "rights-016": {
      "has_risk": null,
      "confidence": "none",
      "reasoning": "전입신고일 데이터가 없어 대항력 발생 시점을 판단할 수 없습니다."
    },
    "eviction-007": {
      "has_risk": null,
      "confidence": "none",
      "reasoning": "점유 현황 상세 데이터가 없습니다."
    },
    "rights-019": {
      "has_risk": false,
      "confidence": "high",
      "reasoning": "토지구분이 '전유'이므로 토지와 건물이 일체로 매각됩니다."
    },
    "rights-020": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "비고란에 '유치권 신고 있음'으로 기재되어 있습니다."
    },
    "eviction-003": {
      "has_risk": null,
      "confidence": "none",
      "reasoning": "점유자 유형에 대한 상세 데이터가 없습니다."
    },
    "eviction-004": {
      "has_risk": null,
      "confidence": "none",
      "reasoning": "임차인 보증금 상세 및 소액임차인 요건 데이터가 없습니다."
    },
    "eviction-006": {
      "has_risk": null,
      "confidence": "none",
      "reasoning": "배당 상세 데이터가 없습니다."
    }
  }
}
```

- [ ] **Step 4: Implement MockLlmAdapter**

Create `app/adapters/mock_llm_adapter.rb`:

```ruby
class MockLlmAdapter < LlmAdapter
  FIXTURE_PATH = Rails.root.join("test/fixtures/files/ai_inspection_response.json")

  def analyze(system:, prompt:)
    JSON.parse(File.read(FIXTURE_PATH))
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bundle exec bin/rails test test/adapters/mock_llm_adapter_test.rb -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/adapters/mock_llm_adapter.rb test/fixtures/files/ai_inspection_response.json test/adapters/mock_llm_adapter_test.rb
git commit -m "feat: add MockLlmAdapter with fixture-based responses"
```

---

### Task 4: Create AnthropicLlmAdapter (stub)

**Files:**
- Create: `app/adapters/anthropic_llm_adapter.rb`
- Test: `test/adapters/anthropic_llm_adapter_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/adapters/anthropic_llm_adapter_test.rb`:

```ruby
require "test_helper"

class AnthropicLlmAdapterTest < ActiveSupport::TestCase
  test "raises NotImplementedError with helpful message" do
    adapter = AnthropicLlmAdapter.new
    error = assert_raises(NotImplementedError) do
      adapter.analyze(system: "test", prompt: "test")
    end
    assert_match(/API key/, error.message)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec bin/rails test test/adapters/anthropic_llm_adapter_test.rb -v`
Expected: FAIL — `NameError: uninitialized constant AnthropicLlmAdapter`

- [ ] **Step 3: Implement stub**

Create `app/adapters/anthropic_llm_adapter.rb`:

```ruby
class AnthropicLlmAdapter < LlmAdapter
  TIMEOUT_SECONDS = 30

  # Future implementation will:
  # 1. Use response_format: { type: "json" } to force pure JSON from API
  # 2. Use sanitize_and_parse_json as fallback for markdown-wrapped responses
  # 3. Set HTTP timeout to TIMEOUT_SECONDS — on timeout, raises error
  #    which PropertyInspectionService catches to trigger InspectionRunner fallback
  def analyze(system:, prompt:)
    raise NotImplementedError,
      "AnthropicLlmAdapter requires ANTHROPIC_API_KEY. " \
      "Set USE_MOCK=true for development, or configure API key for production."
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec bin/rails test test/adapters/anthropic_llm_adapter_test.rb -v`
Expected: PASS

- [ ] **Step 5: Run LlmAdapter tests (Task 2) now that both subclasses exist**

Run: `bundle exec bin/rails test test/adapters/llm_adapter_test.rb -v`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add app/adapters/anthropic_llm_adapter.rb test/adapters/anthropic_llm_adapter_test.rb
git commit -m "feat: add AnthropicLlmAdapter stub for future API integration"
```

---

### Task 5: Create PropertyDataAssembler

**Files:**
- Create: `app/services/inspection/property_data_assembler.rb`
- Test: `test/services/inspection/property_data_assembler_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/services/inspection/property_data_assembler_test.rb`:

```ruby
require "test_helper"

class Inspection::PropertyDataAssemblerTest < ActiveSupport::TestCase
  test "assembles basic property info" do
    property = properties(:risky_villa)
    text = Inspection::PropertyDataAssembler.call(property)
    assert_includes text, "2026타경10002"
    assert_includes text, "빌라"
    assert_includes text, "경기도 수원시 영통구 200-2"
    assert_includes text, "300,000,000"
  end

  test "includes sale detail fields" do
    property = properties(:risky_villa)
    text = Inspection::PropertyDataAssembler.call(property)
    assert_includes text, "을구 1번 주택임차권등기"
    assert_includes text, "유치권 신고 있음"
  end

  test "marks missing fields as 정보 없음" do
    property = properties(:unanalyzed_officetel)
    text = Inspection::PropertyDataAssembler.call(property)
    assert_includes text, "(정보 없음)"
  end

  test "includes appraisal points when present" do
    property = properties(:safe_apartment)
    # Create an appraisal point for the test
    property.appraisal_points.create!(item_code: "00083001", content: "본건은 테스트 아파트입니다.")
    text = Inspection::PropertyDataAssembler.call(property)
    assert_includes text, "본건은 테스트 아파트입니다."
  end

  test "includes auction schedules when present" do
    property = properties(:safe_apartment)
    property.auction_schedules.create!(
      schedule_date: "2026-05-01", schedule_type: "매각기일",
      min_price: 560000000, result_code: "유찰"
    )
    text = Inspection::PropertyDataAssembler.call(property)
    assert_includes text, "2026-05-01"
    assert_includes text, "매각기일"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec bin/rails test test/services/inspection/property_data_assembler_test.rb -v`
Expected: FAIL — `NameError: uninitialized constant Inspection::PropertyDataAssembler`

- [ ] **Step 3: Create directory and implement**

Run: `mkdir -p app/services/inspection`

Create `app/services/inspection/property_data_assembler.rb`:

```ruby
module Inspection
  class PropertyDataAssembler
    def self.call(property)
      new(property).call
    end

    def initialize(property)
      @property = property
      @property.sale_detail # eager load
      @property.appraisal_points.load
      @property.land_details.load
      @property.auction_schedules.load
    end

    def call
      sections = [
        basic_info_section,
        sale_detail_section,
        appraisal_section,
        land_section,
        auction_section
      ]
      sections.join("\n\n")
    end

    private

    def basic_info_section
      p = @property
      <<~TEXT
        [물건 기본 정보]
        사건번호: #{p.case_number}
        물건종류: #{p.property_type}
        소재지: #{p.address}
        감정가: #{format_price(p.appraisal_price)}
        최저입찰가: #{format_price(p.min_bid_price)}
        상태: #{val(p.status)}
        유찰횟수: #{p.failed_bid_count}회
        조회수: #{p.view_count}회
        사건유형: #{val(p.case_type)}
        청구금액: #{format_price(p.claim_amount)}
        건물명: #{val(p.building_name)}
        건물상세: #{val(p.building_detail)}
        건물구조: #{val(p.building_structure)}
        전용면적: #{p.exclusive_area ? "#{p.exclusive_area}㎡" : "(정보 없음)"}
        토지구분: #{val(p.land_category)}
        비고: #{val(p.remarks)}
        특별매각조건코드: #{val(p.special_conditions_code)}
        물건수: #{p.property_count}
      TEXT
    end

    def sale_detail_section
      sd = @property.sale_detail
      return "[매각물건명세서]\n(상세 데이터 미수집)" unless sd

      <<~TEXT
        [매각물건명세서]
        소멸되지않는권리: #{val(sd.non_extinguished_rights)}
        물건명세비고: #{val(sd.specification_remarks)}
        매각물건비고: #{val(sd.goods_remarks)}
        법정지상권: #{val(sd.superficies_details)}
        선순위저당: #{val(sd.senior_mortgage_basis)}
        지분내역: #{val(sd.share_description)}
        배당요구종기: #{sd.dividend_demand_deadline || "(정보 없음)"}
      TEXT
    end

    def appraisal_section
      points = @property.appraisal_points
      return "[감정평가서 주요사항]\n(정보 없음)" if points.empty?

      lines = points.map { |ap| "- #{ap.content}" }
      "[감정평가서 주요사항]\n#{lines.join("\n")}"
    end

    def land_section
      details = @property.land_details
      return "[토지 내역]\n(정보 없음)" if details.empty?

      lines = details.map { |ld| "- #{ld.land_type} #{ld.address} #{ld.land_category} #{ld.land_area} #{ld.share_ratio}" }
      "[토지 내역]\n#{lines.join("\n")}"
    end

    def auction_section
      schedules = @property.auction_schedules.order(:schedule_date)
      return "[경매 일정]\n(정보 없음)" if schedules.empty?

      lines = schedules.map do |s|
        "- #{s.schedule_date} #{s.schedule_type} 최저가=#{format_price(s.min_price)} 결과=#{val(s.result_code)}"
      end
      "[경매 일정]\n#{lines.join("\n")}"
    end

    def val(v)
      v.present? ? v : "(정보 없음)"
    end

    def format_price(amount)
      return "(정보 없음)" if amount.nil? || amount.zero?
      ActiveSupport::NumberHelper.number_to_delimited(amount) + "원"
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec bin/rails test test/services/inspection/property_data_assembler_test.rb -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection/property_data_assembler.rb test/services/inspection/property_data_assembler_test.rb
git commit -m "feat: add PropertyDataAssembler for LLM prompt data preparation"
```

---

### Task 6: Create InspectionPromptBuilder

**Files:**
- Create: `app/services/inspection/inspection_prompt_builder.rb`
- Test: `test/services/inspection/inspection_prompt_builder_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/services/inspection/inspection_prompt_builder_test.rb`:

```ruby
require "test_helper"

class Inspection::InspectionPromptBuilderTest < ActiveSupport::TestCase
  setup do
    @property_text = "[물건 기본 정보]\n사건번호: 2026타경10002\n물건종류: 빌라"
    @items = InspectionItem.where(tab: :rights_analysis).ordered
  end

  test "returns hash with system and user keys" do
    result = Inspection::InspectionPromptBuilder.call(property_text: @property_text, items: @items)
    assert_kind_of Hash, result
    assert result.key?(:system)
    assert result.key?(:user)
  end

  test "system prompt contains expert persona" do
    result = Inspection::InspectionPromptBuilder.call(property_text: @property_text, items: @items)
    assert_includes result[:system], "부동산 경매 권리분석 전문가"
  end

  test "system prompt contains JSON response format" do
    result = Inspection::InspectionPromptBuilder.call(property_text: @property_text, items: @items)
    assert_includes result[:system], "has_risk"
    assert_includes result[:system], "confidence"
    assert_includes result[:system], "reasoning"
  end

  test "user prompt contains property data" do
    result = Inspection::InspectionPromptBuilder.call(property_text: @property_text, items: @items)
    assert_includes result[:user], "2026타경10002"
  end

  test "user prompt contains all inspection items with yes_means_safe flag" do
    result = Inspection::InspectionPromptBuilder.call(property_text: @property_text, items: @items)
    @items.each do |item|
      assert_includes result[:user], item.code
      assert_includes result[:user], "yes_means_safe=#{item.yes_means_safe?}"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec bin/rails test test/services/inspection/inspection_prompt_builder_test.rb -v`
Expected: FAIL — `NameError: uninitialized constant Inspection::InspectionPromptBuilder`

- [ ] **Step 3: Implement**

Create `app/services/inspection/inspection_prompt_builder.rb`:

```ruby
module Inspection
  class InspectionPromptBuilder
    SYSTEM_PROMPT = <<~PROMPT
      당신은 대한민국 부동산 경매 권리분석 전문가입니다.
      법원경매 물건 데이터를 분석하여 아래 점검 항목에 대해 판정해주세요.

      [판정 규칙]
      - 각 항목에 대해 has_risk(위험 여부), confidence(확신도), reasoning(판정 근거)을 반환하세요.
      - 데이터가 부족하여 판단할 수 없는 항목은 has_risk: null, confidence: "none"으로 반환하세요.
      - yes_means_safe=false인 항목은 "예"가 위험을 의미합니다. has_risk는 항상 "이 항목이 위험한가?"를 기준으로 판정하세요.
      - reasoning은 반드시 데이터에서 확인한 구체적 근거를 인용하세요.

      [응답 형식]
      반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트를 포함하지 마세요.
      {
        "results": {
          "<item_code>": {
            "has_risk": true | false | null,
            "confidence": "high" | "medium" | "none",
            "reasoning": "판정 근거 (한국어)"
          }
        }
      }
    PROMPT

    def self.call(property_text:, items:)
      new(property_text:, items:).call
    end

    def initialize(property_text:, items:)
      @property_text = property_text
      @items = items
    end

    def call
      {
        system: SYSTEM_PROMPT.strip,
        user: build_user_prompt
      }
    end

    private

    def build_user_prompt
      item_lines = @items.map do |item|
        "#{item.code}: #{item.question} (yes_means_safe=#{item.yes_means_safe?}, priority=#{item.priority})"
      end

      <<~PROMPT
        [물건 데이터]
        #{@property_text}

        [점검 항목]
        #{item_lines.join("\n")}
      PROMPT
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec bin/rails test test/services/inspection/inspection_prompt_builder_test.rb -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection/inspection_prompt_builder.rb test/services/inspection/inspection_prompt_builder_test.rb
git commit -m "feat: add InspectionPromptBuilder for LLM prompt generation"
```

---

### Task 7: Create InspectionResultMapper

**Files:**
- Create: `app/services/inspection/inspection_result_mapper.rb`
- Test: `test/services/inspection/inspection_result_mapper_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/services/inspection/inspection_result_mapper_test.rb`:

```ruby
require "test_helper"

class Inspection::InspectionResultMapperTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    @user = users(:guest)
    @items = InspectionItem.where(tab: :rights_analysis).ordered
    @response = JSON.parse(File.read(Rails.root.join("test/fixtures/files/ai_inspection_response.json")))
  end

  test "creates inspection results for high confidence items" do
    results = Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-002")
    assert result.ai?
    assert result.has_risk
    assert_equal "high", result.evidence["confidence"]
    assert result.evidence["reasoning"].present?
    assert_equal "AI 분석", result.evidence["source_label"]
  end

  test "creates inspection results for medium confidence items" do
    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-001")
    assert result.ai?
    assert_equal false, result.has_risk
    assert_equal "medium", result.evidence["confidence"]
    assert_equal "AI 분석 (추론)", result.evidence["source_label"]
  end

  test "leaves none confidence items unanswered" do
    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-003")
    assert_nil result.source_type
    assert_nil result.has_risk
  end

  test "does not overwrite manual answers" do
    # manual_risk fixture: risky_villa + manual_001 = manual, has_risk: true
    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("manual-001")
    assert result.manual?
    assert result.has_risk
    assert_equal "임차인과 협의 완료", result.resolution_note
  end

  test "overwrites previous auto answers with ai" do
    # risky_villa_rights_011 fixture: auto, has_risk: true
    Inspection::InspectionResultMapper.call(
      response: @response, property: @property, user: @user, items: @items
    )
    result = find_result("rights-011")
    assert result.ai?
  end

  private

  def find_result(code)
    item = InspectionItem.find_by(code: code)
    InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec bin/rails test test/services/inspection/inspection_result_mapper_test.rb -v`
Expected: FAIL — `NameError: uninitialized constant Inspection::InspectionResultMapper`

- [ ] **Step 3: Implement**

Create `app/services/inspection/inspection_result_mapper.rb`:

```ruby
module Inspection
  class InspectionResultMapper
    def self.call(response:, property:, user:, items:)
      new(response:, property:, user:, items:).call
    end

    def initialize(response:, property:, user:, items:)
      @response = response
      @property = property
      @user = user
      @items = items
    end

    def call
      results = @response["results"] || {}

      @items.map do |item|
        result = @property.inspection_results.find_or_initialize_by(
          inspection_item: item, user: @user
        )

        next result if user_manually_answered?(result)

        ai_result = results[item.code]
        if ai_result.nil? || ai_result["confidence"] == "none"
          unless user_manually_answered?(result)
            result.assign_attributes(source_type: nil, has_risk: nil, evidence: nil)
          end
        else
          source_label = ai_result["confidence"] == "high" ? "AI 분석" : "AI 분석 (추론)"
          result.assign_attributes(
            source_type: "ai",
            has_risk: ai_result["has_risk"],
            evidence: {
              source_label: source_label,
              confidence: ai_result["confidence"],
              reasoning: ai_result["reasoning"]
            }
          )
        end

        result.save!
        result
      end
    end

    private

    def user_manually_answered?(result)
      result.persisted? && result.manual?
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec bin/rails test test/services/inspection/inspection_result_mapper_test.rb -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection/inspection_result_mapper.rb test/services/inspection/inspection_result_mapper_test.rb
git commit -m "feat: add InspectionResultMapper for LLM response to DB mapping"
```

---

### Task 8: Create AiInspectionRunner

**Files:**
- Create: `app/services/ai_inspection_runner.rb`
- Test: `test/services/ai_inspection_runner_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/services/ai_inspection_runner_test.rb`:

```ruby
require "test_helper"

class AiInspectionRunnerTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    @user = users(:guest)
    ENV["USE_MOCK"] = "true"
  end

  teardown do
    ENV.delete("USE_MOCK")
  end

  test "creates inspection results for all rights_analysis items" do
    # Clear existing fixtures for clean test
    @property.inspection_results.where(user: @user).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)

    items = InspectionItem.where(tab: :rights_analysis)
    items.each do |item|
      result = InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
      assert_not_nil result, "Missing result for #{item.code}"
    end
  end

  test "sets source_type to ai for high confidence results" do
    @property.inspection_results.where(user: @user).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)

    result = find_result("rights-002")
    assert result.ai?
    assert result.has_risk
    assert_equal "AI 분석", result.evidence["source_label"]
  end

  test "preserves manual answers" do
    # manual_risk fixture exists: risky_villa + manual_001 = manual
    AiInspectionRunner.call(property: @property, user: @user)

    result = find_result("manual-001")
    assert result.manual?
  end

  test "is idempotent — running twice does not create duplicates" do
    @property.inspection_results.where(user: @user).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)
    count_after_first = InspectionResult.where(property: @property, user: @user).count

    AiInspectionRunner.call(property: @property, user: @user)
    count_after_second = InspectionResult.where(property: @property, user: @user).count

    assert_equal count_after_first, count_after_second
  end

  private

  def find_result(code)
    item = InspectionItem.find_by(code: code)
    InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec bin/rails test test/services/ai_inspection_runner_test.rb -v`
Expected: FAIL — `NameError: uninitialized constant AiInspectionRunner`

- [ ] **Step 3: Implement**

Create `app/services/ai_inspection_runner.rb`:

```ruby
class AiInspectionRunner
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    text = Inspection::PropertyDataAssembler.call(@property)
    items = InspectionItem.ordered
    prompt = Inspection::InspectionPromptBuilder.call(property_text: text, items: items)
    response = LlmAdapter.for.analyze(system: prompt[:system], prompt: prompt[:user])
    Inspection::InspectionResultMapper.call(
      response: response, property: @property, user: @user, items: items
    )
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec bin/rails test test/services/ai_inspection_runner_test.rb -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/ai_inspection_runner.rb test/services/ai_inspection_runner_test.rb
git commit -m "feat: add AiInspectionRunner orchestrating LLM-based inspection"
```

---

### Task 9: Update PropertyInspectionService with fallback

**Files:**
- Modify: `app/services/property_inspection_service.rb:11-13`
- Test: `test/services/property_inspection_service_test.rb` (create)

- [ ] **Step 1: Write the failing test**

Create `test/services/property_inspection_service_test.rb`:

```ruby
require "test_helper"

class PropertyInspectionServiceTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    @user = users(:guest)
  end

  test "uses AiInspectionRunner when USE_MOCK is true" do
    ENV["USE_MOCK"] = "true"
    @property.inspection_results.where(user: @user).destroy_all

    PropertyInspectionService.call(property: @property, user: @user)

    result = find_result("rights-002")
    assert result.ai?, "Expected AI source_type but got #{result.source_type}"
  ensure
    ENV.delete("USE_MOCK")
  end

  test "falls back to InspectionRunner when AI fails" do
    ENV.delete("USE_MOCK")
    @property.inspection_results.where(user: @user).destroy_all

    # AnthropicLlmAdapter raises NotImplementedError → triggers fallback
    PropertyInspectionService.call(property: @property, user: @user)

    result = find_result("rights-011")
    assert result.auto?, "Expected auto source_type from fallback but got #{result.source_type}"
  end

  private

  def find_result(code)
    item = InspectionItem.find_by(code: code)
    InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec bin/rails test test/services/property_inspection_service_test.rb -v`
Expected: First test FAIL — AI runner not called yet (still using InspectionRunner directly)

- [ ] **Step 3: Update PropertyInspectionService**

Replace the `call` method in `app/services/property_inspection_service.rb`:

```ruby
class PropertyInspectionService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    begin
      AiInspectionRunner.call(property: @property, user: @user)
    rescue => e
      Rails.logger.warn("AI inspection failed: #{e.message}, falling back to rule-based")
      InspectionRunner.call(property: @property, user: @user)
    end

    RightsAnalysisService.call(property: @property, user: @user)
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec bin/rails test test/services/property_inspection_service_test.rb -v`
Expected: PASS

- [ ] **Step 5: Run full test suite**

Run: `bundle exec bin/rails test`
Expected: All tests pass (existing InspectionRunner tests still pass since fallback works)

- [ ] **Step 6: Commit**

```bash
git add app/services/property_inspection_service.rb test/services/property_inspection_service_test.rb
git commit -m "feat: update PropertyInspectionService with AI-first, rule-based fallback"
```

---

### Task 10: Update InspectionItemComponent for AI badge

**Files:**
- Modify: `app/components/inspection_item_component.rb:10-11,24-31,104-106`
- Test: `test/components/inspection_item_component_test.rb` (create or modify)

- [ ] **Step 1: Write the failing test**

Create `test/components/inspection_item_component_test.rb`:

```ruby
require "test_helper"

class InspectionItemComponentTest < ActiveSupport::TestCase
  setup do
    @item = inspection_items(:rights_002)
    @user = users(:guest)
    @property = properties(:risky_villa)
  end

  test "ai source badge text returns AI 분석" do
    result = InspectionResult.new(
      property: @property, inspection_item: @item, user: @user,
      source_type: :ai, has_risk: true,
      evidence: { "source_label" => "AI 분석", "confidence" => "high", "reasoning" => "테스트" }
    )
    component = InspectionItemComponent.new(result: result)
    assert_equal "AI 분석", component.send(:source_badge_text)
  end

  test "ai source shows evidence" do
    result = InspectionResult.new(
      property: @property, inspection_item: @item, user: @user,
      source_type: :ai, has_risk: true,
      evidence: { "source_label" => "AI 분석", "confidence" => "high", "reasoning" => "테스트" }
    )
    component = InspectionItemComponent.new(result: result)
    assert component.send(:evidence_present?)
  end

  test "auto source badge text returns 자동" do
    result = InspectionResult.new(
      property: @property, inspection_item: @item, user: @user,
      source_type: :auto, has_risk: false,
      evidence: { "source_label" => "매각물건명세서" }
    )
    component = InspectionItemComponent.new(result: result)
    assert_equal "자동", component.send(:source_badge_text)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bundle exec bin/rails test test/components/inspection_item_component_test.rb -v`
Expected: FAIL — `"AI 분석"` not returned (current code returns "직접 확인" for non-auto types)

- [ ] **Step 3: Update component**

In `app/components/inspection_item_component.rb`, update the relevant methods:

Replace line 10-12:
```ruby
def auto_or_ai_source? = @result.source_type.in?(%w[auto ai])
def ai_source? = @result.source_type == "ai"
def auto_source? = @result.source_type == "auto"
def manual_source? = @result.source_type == "manual"
def overridden? = manual_source? && @result.auto_value.present?
```

Replace `source_badge_text` method:
```ruby
def source_badge_text
  if ai_source?
    "AI 분석"
  elsif auto_source?
    "자동"
  elsif overridden?
    "수정됨"
  else
    "직접 확인"
  end
end
```

Replace `source_badge_classes` method:
```ruby
def source_badge_classes
  if ai_source?
    "bg-blue-100 text-blue-700 ring-1 ring-inset ring-blue-600/20 dark:bg-blue-900/30 dark:text-blue-300 dark:ring-blue-400/20"
  elsif auto_source?
    "bg-slate-200 text-slate-600 dark:bg-slate-700 dark:text-slate-400"
  elsif overridden?
    "bg-amber-100 text-amber-700 ring-1 ring-inset ring-amber-600/20 dark:bg-amber-900/30 dark:text-amber-300 dark:ring-amber-400/20"
  else
    "bg-amber-100 text-amber-700 ring-1 ring-inset ring-amber-600/20 dark:bg-amber-900/30 dark:text-amber-300 dark:ring-amber-400/20"
  end
end
```

Replace `risk_classes` — use `auto_or_ai_source?` where `auto_source?` was used:
```ruby
def risk_classes
  if !auto_or_ai_source? && @result.has_risk.nil?
    "border-slate-400 bg-slate-100 dark:border-slate-600 dark:bg-slate-800/50"
  elsif @result.has_risk
    auto_or_ai_source? ? "border-red-400 bg-red-100 dark:border-red-600 dark:bg-red-900/20" : "border-yellow-400 bg-yellow-100 dark:border-yellow-600 dark:bg-yellow-900/20"
  else
    "border-green-400 bg-green-100 dark:border-green-600 dark:bg-green-900/20"
  end
end
```

Replace `status_text`:
```ruby
def status_text
  if !auto_or_ai_source? && @result.has_risk.nil? then "미입력"
  elsif @result.has_risk then auto_or_ai_source? ? "위험" : "위험 확인"
  else "안전"
  end
end
```

Replace `evidence_present?`:
```ruby
def evidence_present?
  auto_or_ai_source? && @result.evidence.present?
end
```

Replace `show_auto_resolution?`, `show_manual_input?`, `show_edit_mode?`:
```ruby
def show_auto_resolution? = @show_resolution && auto_or_ai_source? && @result.has_risk
def show_manual_input? = @show_resolution && !auto_or_ai_source? && !overridden?
def show_edit_mode? = @show_resolution && (auto_or_ai_source? || overridden?)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bundle exec bin/rails test test/components/inspection_item_component_test.rb -v`
Expected: PASS

- [ ] **Step 5: Run full test suite**

Run: `bundle exec bin/rails test`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add app/components/inspection_item_component.rb test/components/inspection_item_component_test.rb
git commit -m "feat: update InspectionItemComponent to display AI analysis badge"
```

---

### Task 11: Full integration test and cleanup

**Files:**
- Test: `test/integration/ai_inspection_flow_test.rb` (create)

- [ ] **Step 1: Write integration test**

Create `test/integration/ai_inspection_flow_test.rb`:

```ruby
require "test_helper"

class AiInspectionFlowTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    @user = users(:guest)
    ENV["USE_MOCK"] = "true"
  end

  teardown do
    ENV.delete("USE_MOCK")
  end

  test "full AI inspection pipeline: data assembly → prompt → mock LLM → DB mapping" do
    @property.inspection_results.where(user: @user).destroy_all

    PropertyInspectionService.call(property: @property, user: @user)

    # Verify AI results were created
    rights_items = InspectionItem.where(tab: :rights_analysis)
    ai_results = InspectionResult.where(
      property: @property, user: @user, source_type: :ai
    )
    assert ai_results.count > 0, "Expected AI results to be created"

    # Verify high confidence result
    rights_002 = find_result("rights-002")
    assert rights_002.ai?
    assert rights_002.has_risk
    assert_equal "AI 분석", rights_002.evidence["source_label"]
    assert rights_002.evidence["reasoning"].present?

    # Verify none confidence result left unanswered
    rights_003 = find_result("rights-003")
    assert_nil rights_003.source_type

    # Verify manual answer preserved
    manual = find_result("manual-001")
    assert manual.manual?
  end

  test "fallback to InspectionRunner when USE_MOCK is false and no API key" do
    ENV.delete("USE_MOCK")
    @property.inspection_results.where(user: @user).destroy_all

    PropertyInspectionService.call(property: @property, user: @user)

    # Should have auto results from InspectionRunner fallback
    rights_011 = find_result("rights-011")
    assert rights_011.auto?
  end

  private

  def find_result(code)
    item = InspectionItem.find_by(code: code)
    InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
  end
end
```

- [ ] **Step 2: Run integration test**

Run: `bundle exec bin/rails test test/integration/ai_inspection_flow_test.rb -v`
Expected: PASS

- [ ] **Step 3: Run full test suite**

Run: `bundle exec bin/rails test`
Expected: All tests pass

- [ ] **Step 4: Run linting**

Run: `bundle exec bin/rubocop app/adapters/llm_adapter.rb app/adapters/mock_llm_adapter.rb app/adapters/anthropic_llm_adapter.rb app/services/ai_inspection_runner.rb app/services/inspection/ app/services/property_inspection_service.rb app/models/inspection_result.rb app/components/inspection_item_component.rb`

Fix any style issues.

- [ ] **Step 5: Commit integration test**

```bash
git add test/integration/ai_inspection_flow_test.rb
git commit -m "test: add end-to-end AI inspection flow integration test"
```

- [ ] **Step 6: Run full CI pipeline**

Run: `bundle exec bin/ci`
Expected: All checks pass (rubocop, brakeman, tests, seed check)
