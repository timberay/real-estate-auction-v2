# Checklist Property-Type Awareness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make checklist items aware of property type so that apartment-only questions are handled correctly for non-apartment properties, questions use neutral terminology, reasoning displays with line breaks, and AI opinions are preserved even when confidence is "none".

**Architecture:** Add `applicable_types` JSON field to InspectionItem. Update PdfPromptBuilder to instruct AI to use property_type from metadata. Update InspectionResultMapper to server-side validate type applicability and preserve AI opinions for "none" confidence items. Fix reasoning line breaks via CSS.

**Tech Stack:** Rails 8.1, Minitest, ViewComponent, SQLite

---

### Task 1: Fix reasoning line breaks in evidence block (CSS)

**Files:**
- Modify: `app/components/inspection_item_component.html.erb:54-56`
- Test: `test/components/inspection_item_component_test.rb`

- [ ] **Step 1: Write the failing test**

Add to `test/components/inspection_item_component_test.rb`:

```ruby
test "renders reasoning with line breaks preserved" do
  result = inspection_results(:risky_villa_rights_011)
  result.update!(
    source_type: :ai, has_risk: true,
    evidence: { "source_label" => "AI 분석", "confidence" => "high", "reasoning" => "첫째 줄입니다.\n둘째 줄입니다." }
  )
  render_inline(InspectionItemComponent.new(result: result))

  assert_selector "[data-evidence] span.whitespace-pre-line", text: /첫째 줄입니다/
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/inspection_item_component_test.rb -n "test_renders_reasoning_with_line_breaks_preserved"`
Expected: FAIL — no element matching `span.whitespace-pre-line`

- [ ] **Step 3: Add whitespace-pre-line class to reasoning span**

In `app/components/inspection_item_component.html.erb`, change line 55:

```erb
<%# FROM: %>
<div class="<%= evidence_label_classes %>"><span class="<%= evidence_value_classes %>"><%= evidence["reasoning"] %></span></div>

<%# TO: %>
<div class="<%= evidence_label_classes %>"><span class="whitespace-pre-line <%= evidence_value_classes %>"><%= evidence["reasoning"] %></span></div>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/inspection_item_component_test.rb -n "test_renders_reasoning_with_line_breaks_preserved"`
Expected: PASS

- [ ] **Step 5: Run full component test suite**

Run: `bin/rails test test/components/inspection_item_component_test.rb`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add app/components/inspection_item_component.html.erb test/components/inspection_item_component_test.rb
git commit -m "fix: preserve line breaks in evidence reasoning display"
```

---

### Task 2: Add applicable_types column to InspectionItem

**Files:**
- Create: `db/migrate/TIMESTAMP_add_applicable_types_to_inspection_items.rb`
- Modify: `app/models/inspection_item.rb`
- Test: `test/models/inspection_item_test.rb`

- [ ] **Step 1: Generate migration**

Run: `bin/rails generate migration AddApplicableTypesToInspectionItems applicable_types:json`

- [ ] **Step 2: Run migration**

Run: `bin/rails db:migrate`

- [ ] **Step 3: Write test for applicable_for? method**

Add to `test/models/inspection_item_test.rb`:

```ruby
test "applicable_for? returns true when applicable_types is nil (applies to all)" do
  item = inspection_items(:rights_002)
  item.update!(applicable_types: nil)
  assert item.applicable_for?("단독주택")
  assert item.applicable_for?("아파트")
end

test "applicable_for? returns true when property_type is in applicable_types" do
  item = inspection_items(:rights_002)
  item.update!(applicable_types: ["아파트", "오피스텔"])
  assert item.applicable_for?("아파트")
end

test "applicable_for? returns false when property_type is not in applicable_types" do
  item = inspection_items(:rights_002)
  item.update!(applicable_types: ["아파트"])
  refute item.applicable_for?("단독주택")
end
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `bin/rails test test/models/inspection_item_test.rb`
Expected: FAIL — `applicable_for?` not defined

- [ ] **Step 5: Add applicable_for? method to InspectionItem**

In `app/models/inspection_item.rb`, add after the `scope` lines:

```ruby
def applicable_for?(property_type)
  applicable_types.blank? || applicable_types.include?(property_type)
end
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bin/rails test test/models/inspection_item_test.rb`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add db/migrate/*add_applicable_types* app/models/inspection_item.rb test/models/inspection_item_test.rb
git commit -m "feat: add applicable_types column and applicable_for? method to InspectionItem"
```

---

### Task 3: Update checklist JSON — neutralize question text and add applicable_types

**Files:**
- Modify: `db/seeds/checklist_items_summary.json`

This task updates 8 checklist items. Changes are grouped by type:

**A. Neutralize "빌라" → "해당 건축물" (2 items):**

- [ ] **Step 1: Update location-004 (빌라 방 구조)**

Find `"id": "location-004"` and change:

```json
{
  "id": "location-004",
  "tab": "물건분석",
  "tab_position": 9,
  "category": "입지분석",
  "question": "해당 건축물의 방 구조가 투룸 이상입니까?",
  "description": "투룸 이상이 원룸보다 임대·매매가 유리합니다. 방 구조는 건축물 가치를 결정하는 핵심 변수입니다.",
  "logic": {
    "yes": "실거주자 수요가 있습니다.",
    "no": "실거주자가 찾지 않는 구조입니다."
  },
  "priority": "상",
  "merged_from": "resale-001"
}
```

- [ ] **Step 2: Update location-007 (빌라 수요)**

Find `"id": "location-007"` and change:

```json
{
  "id": "location-007",
  "tab": "수익분석",
  "tab_position": 14,
  "category": "입지분석",
  "question": "해당 건축물이 위치한 지역에 매수 수요(재개발 이주 수요 또는 실거주 수요)가 있습니까?",
  "description": "주거지역/상업지역/혼합지역에 따라 생활 환경과 시세 흐름이 다릅니다.",
  "logic": {
    "yes": "매수 수요가 있어 매매가 용이합니다.",
    "no": "매수 수요가 적어 매도가 어려울 수 있습니다."
  },
  "priority": "중"
}
```

**B. Update elevator question (1 item):**

- [ ] **Step 3: Update property-007 (엘리베이터)**

Find `"id": "property-007"` and change:

```json
{
  "id": "property-007",
  "tab": "물건분석",
  "tab_position": 7,
  "category": "물건 기본 필터링",
  "question": "해당 건물이 4층 이상이면서 엘리베이터가 설치되어 있습니까?",
  "description": "4층 이상 건물에서 엘리베이터 유무는 매매·임대가에 큰 영향을 미칩니다. 건축물대장 확인과 층수 영향을 종합 판단합니다.",
  "logic": {
    "yes": "엘리베이터가 있어 층수 제약이 없습니다.",
    "no": "4층 이상인데 엘리베이터가 없으면 매매·임대가 어려울 수 있습니다."
  },
  "priority": "중"
}
```

**C. Neutralize "아파트" → "해당 물건" and add applicable_types (3 items):**

- [ ] **Step 4: Update finance-003 (근저당 은행 지점) — add applicable_types**

Find `"id": "finance-003"` and change:

```json
{
  "id": "finance-003",
  "tab": "수익분석",
  "tab_position": 2,
  "category": "자금&대출 분석",
  "question": "등기부등본에 해당 물건에 근저당을 설정해준 이력이 있는 작은 은행 지점이 명시되어 있습니까?",
  "description": "이전에 해당 물건에 대출해준 은행은 담보 가치를 이미 인정한 것이므로, 같은 지점에 문의하면 대출 승인 가능성이 높습니다.",
  "logic": {
    "yes": "대출 승인 확률이 높아 자금 융통에 유리합니다.",
    "no": "시중 은행 대출이 거절될 수 있습니다."
  },
  "priority": "중",
  "applicable_types": ["아파트"]
}
```

- [ ] **Step 5: Update market-007 (세대수 대비 매물 비율) — add applicable_types**

Find `"id": "market-007"` and change:

```json
{
  "id": "market-007",
  "tab": "수익분석",
  "tab_position": 10,
  "category": "시세&수익성 분석",
  "question": "단지 총 세대수 대비 현재 나와 있는 매물 비율이 적정 수준(5% 이하)입니까?",
  "description": "매물 비율이 높으면 공급 과잉으로 매도가 어렵고, 낮으면 희소성이 있어 유리합니다.",
  "logic": {
    "yes": "준수한 수준의 단지입니다.",
    "no": "매물이 기준치 이상으로 쌓여 있어 환금성에 불리할 수 있습니다."
  },
  "priority": "중",
  "applicable_types": ["아파트", "오피스텔"]
}
```

- [ ] **Step 6: Update market-008 (신축 입주 시기) — add applicable_types**

Find `"id": "market-008"` and change:

```json
{
  "id": "market-008",
  "tab": "수익분석",
  "tab_position": 11,
  "category": "시세&수익성 분석",
  "question": "금액대가 비슷한 주변 신축 아파트의 입주 시기가 3개월 이상 남아 있습니까?",
  "description": "인근 신축 입주가 임박하면 기존 물건의 시세·임대가가 하락 압력을 받습니다. 타이밍 리스크 점검입니다.",
  "logic": {
    "yes": "입주장 리스크가 낮습니다.",
    "no": "전세입자 이동 및 급매 출현으로 가격 하락 위험이 큽니다."
  },
  "priority": "상",
  "applicable_types": ["아파트"]
}
```

- [ ] **Step 7: Commit**

```bash
git add db/seeds/checklist_items_summary.json
git commit -m "refactor: neutralize property-type-specific question text and add applicable_types"
```

---

### Task 4: Update seed loader to persist applicable_types

**Files:**
- Modify: `db/seeds.rb:82-94`

- [ ] **Step 1: Add applicable_types to seed assign_attributes**

In `db/seeds.rb`, find the `item.assign_attributes(` block (around line 82) and add `applicable_types`:

```ruby
  item.assign_attributes(
    tab: tab_key,
    tab_position: attrs["tab_position"],
    category: attrs["category"],
    question: attrs["question"],
    description: attrs["description"],
    logic: attrs["logic"],
    data_source_name: attrs.dig("data_source", 0, "name") || "수동 입력",
    priority: attrs["priority"],
    merged_from: attrs["merged_from"],
    answer_type: attrs["answer_type"],
    yes_means_safe: attrs.fetch("yes_means_safe", true),
    applicable_types: attrs["applicable_types"]
  )
```

- [ ] **Step 2: Run seed to verify**

Run: `bin/rails db:seed`
Expected: No errors

- [ ] **Step 3: Verify in console**

Run: `bin/rails runner "puts InspectionItem.where.not(applicable_types: nil).pluck(:code, :applicable_types).inspect"`
Expected: Shows `finance-003`, `market-007`, `market-008` with their applicable_types arrays

- [ ] **Step 4: Commit**

```bash
git add db/seeds.rb
git commit -m "feat: persist applicable_types from checklist JSON in seed loader"
```

---

### Task 5: Update PdfPromptBuilder to include property_type cross-reference rules

**Files:**
- Modify: `app/services/inspection/pdf_prompt_builder.rb`

- [ ] **Step 1: Add property_type cross-reference rule to SYSTEM_PROMPT**

In `app/services/inspection/pdf_prompt_builder.rb`, add after the `[판정 규칙]` section (after line 22):

```ruby
      [물건 종류별 판정 규칙]
      - 작업 1에서 추출한 property_type을 작업 2의 모든 판정에 반드시 참조하세요.
      - 각 항목에 applicable_types가 명시된 경우, property_type이 해당 목록에 포함되지 않으면:
        has_risk: null, confidence: "none",
        reasoning: "해당 물건은 [property_type]이므로 이 항목([applicable_types 전용])은 직접 확인이 필요합니다. [AI 의견: 문서에서 확인된 관련 정보가 있다면 기술]"
      - property-006 항목(물건 종류가 아파트인지)은 property_type으로 직접 판정하세요:
        아파트이면 has_risk: false, 아파트가 아니면 has_risk: true.
      - property-007 항목(엘리베이터)은 건물 층수가 4층 미만이면 has_risk: false로 판정하세요.
      - market-006 항목(나홀로 건물)은 property_type이 단독주택이면 has_risk: true로 판정하세요.
```

- [ ] **Step 2: Update build_user_prompt to include applicable_types**

Change the `build_user_prompt` method:

```ruby
    def build_user_prompt
      item_lines = @items.map do |item|
        applicable = item.applicable_types.present? ? "applicable_types=#{item.applicable_types.join(',')}" : "applicable_types=all"
        "#{item.code}: #{item.question} (yes_means_safe=#{item.yes_means_safe?}, priority=#{item.priority}, #{applicable})"
      end

      <<~PROMPT
        [첨부 문서]
        (첨부된 PDF 문서들을 분석해주세요)

        [점검 항목]
        #{item_lines.join("\n")}
      PROMPT
    end
```

- [ ] **Step 3: Run existing tests**

Run: `bin/rails test test/services/`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add app/services/inspection/pdf_prompt_builder.rb
git commit -m "feat: add property-type cross-reference rules to PDF prompt builder"
```

---

### Task 6: Update InspectionResultMapper to preserve AI opinions for "none" confidence

**Files:**
- Modify: `app/services/inspection/inspection_result_mapper.rb`
- Modify: `test/services/inspection/inspection_result_mapper_test.rb`
- Modify: `test/fixtures/files/ai_inspection_response.json`

Currently, when confidence is "none", the mapper sets `evidence: nil` which loses the AI's reasoning. We need to preserve the reasoning while keeping `has_risk: nil`.

- [ ] **Step 1: Add test fixture data for "none" confidence with reasoning**

In `test/fixtures/files/ai_inspection_response.json`, add a new result entry inside the `"results"` object (e.g., after the `"manual-001"` entry):

```json
    "rights-009": {
      "has_risk": null,
      "confidence": "none",
      "reasoning": "해당 물건은 단독주택이므로 이 항목(아파트 전용)은 직접 확인이 필요합니다. AI 의견: 등기부등본에서 HUG 관련 기재를 확인할 수 없었습니다."
    }
```

Also add `rights_009` to `test/fixtures/inspection_items.yml`:

```yaml
rights_009:
  code: "rights-009"
  tab: 0
  tab_position: 5
  category: "권리분석"
  question: "대항력 있는 임차인이 없거나, 있더라도 HUG 등 채권자의 대항력 포기 확약서가 제출되어 있습니까?"
  description: "HUG 확약서 확인"
  logic: '{"yes": "안전", "no": "위험"}'
  data_source_name: "수동 입력"
  priority: "상"
  yes_means_safe: true
```

- [ ] **Step 2: Write the failing test**

Add to `test/services/inspection/inspection_result_mapper_test.rb`:

```ruby
test "preserves AI reasoning even when confidence is none" do
  @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

  Inspection::InspectionResultMapper.call(
    response: @response, property: @property, user: @user, items: @items
  )
  result = find_result("rights-009")
  assert_nil result.has_risk
  assert result.evidence.present?, "evidence should be preserved for none confidence"
  assert_equal "none", result.evidence["confidence"]
  assert_equal "AI 분석 (참고)", result.evidence["source_label"]
  assert result.evidence["reasoning"].present?
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bin/rails test test/services/inspection/inspection_result_mapper_test.rb -n "test_preserves_AI_reasoning_even_when_confidence_is_none"`
Expected: FAIL — evidence is nil

- [ ] **Step 4: Update InspectionResultMapper to preserve reasoning for "none" confidence**

In `app/services/inspection/inspection_result_mapper.rb`, replace lines 24-37:

```ruby
        ai_result = results[item.code]
        if ai_result.nil?
          result.assign_attributes(source_type: nil, has_risk: nil, evidence: nil)
        elsif ai_result["confidence"] == "none"
          evidence_attrs = if ai_result["reasoning"].present?
            {
              source_label: "AI 분석 (참고)",
              confidence: "none",
              reasoning: ai_result["reasoning"]
            }
          end
          result.assign_attributes(source_type: "ai", has_risk: nil, evidence: evidence_attrs)
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
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/services/inspection/inspection_result_mapper_test.rb -n "test_preserves_AI_reasoning_even_when_confidence_is_none"`
Expected: PASS

- [ ] **Step 6: Run full mapper test suite**

Run: `bin/rails test test/services/inspection/inspection_result_mapper_test.rb`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add app/services/inspection/inspection_result_mapper.rb test/services/inspection/inspection_result_mapper_test.rb test/fixtures/files/ai_inspection_response.json test/fixtures/inspection_items.yml
git commit -m "feat: preserve AI reasoning in evidence when confidence is none"
```

---

### Task 7: Update evidence display to handle "none" confidence (참고 opinion)

**Files:**
- Modify: `app/components/inspection_item_component.rb:110-111`
- Modify: `app/components/inspection_item_component.html.erb`
- Test: `test/components/inspection_item_component_test.rb`

Currently `evidence_present?` requires `auto_or_ai_source?` which won't match "none" confidence items that have `source_type: "ai"` but `has_risk: nil`. We need to verify this still renders correctly.

- [ ] **Step 1: Write test for rendering evidence when has_risk is nil but evidence exists (AI 참고)**

Add to `test/components/inspection_item_component_test.rb`:

```ruby
test "renders evidence block for ai result with none confidence (참고)" do
  result = inspection_results(:risky_villa_rights_011)
  result.update!(
    source_type: :ai, has_risk: nil,
    evidence: { "source_label" => "AI 분석 (참고)", "confidence" => "none", "reasoning" => "해당 물건은 단독주택이므로 직접 확인이 필요합니다." }
  )
  render_inline(InspectionItemComponent.new(result: result))

  assert_selector "[data-evidence]"
  assert_text "AI 분석 (참고)"
  assert_text "해당 물건은 단독주택이므로 직접 확인이 필요합니다."
end
```

- [ ] **Step 2: Run test to check current behavior**

Run: `bin/rails test test/components/inspection_item_component_test.rb -n "test_renders_evidence_block_for_ai_result_with_none_confidence"`

If it passes, the existing code already handles this case (ai_source? is true, evidence is present). If it fails, fix the `evidence_border_classes` method to handle `has_risk: nil`:

- [ ] **Step 3: Fix evidence_border_classes for nil has_risk (if needed)**

In `app/components/inspection_item_component.rb`, update `evidence_border_classes`:

```ruby
def evidence_border_classes
  if @result.has_risk
    "border-l-red-500 bg-red-500/5 dark:bg-red-500/10"
  elsif @result.has_risk == false
    "border-l-indigo-500 bg-indigo-500/5 dark:bg-indigo-500/10"
  else
    "border-l-slate-400 bg-slate-500/5 dark:bg-slate-500/10"
  end
end

def evidence_header_classes
  if @result.has_risk
    "text-red-400"
  elsif @result.has_risk == false
    "text-indigo-400"
  else
    "text-slate-400"
  end
end

def evidence_label_classes
  if @result.has_risk
    "text-red-300 dark:text-red-400"
  elsif @result.has_risk == false
    "text-indigo-300 dark:text-indigo-400"
  else
    "text-slate-300 dark:text-slate-400"
  end
end
```

- [ ] **Step 4: Run full component test suite**

Run: `bin/rails test test/components/inspection_item_component_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/components/inspection_item_component.rb app/components/inspection_item_component.html.erb test/components/inspection_item_component_test.rb
git commit -m "feat: support evidence display for none-confidence AI opinions"
```

---

### Task 8: Add server-side property_type validation in InspectionResultMapper

**Files:**
- Modify: `app/services/inspection/inspection_result_mapper.rb`
- Test: `test/services/inspection/inspection_result_mapper_test.rb`

This adds a post-processing step: after AI results are mapped, validate that items with `applicable_types` match the property's type from metadata. If they don't match and the AI still gave a definitive answer, override to `has_risk: nil` with a corrective reasoning.

- [ ] **Step 1: Update mapper signature to accept metadata**

In `app/services/inspection/inspection_result_mapper.rb`, change `call` and `initialize`:

```ruby
def self.call(response:, property:, user:, items:)
  new(response:, property:, user:, items:).call
end

def initialize(response:, property:, user:, items:)
  @response = response
  @property = property
  @user = user
  @items = items
  @property_type = response.dig("metadata", "property_type")
end
```

- [ ] **Step 2: Write the failing test**

Add to `test/services/inspection/inspection_result_mapper_test.rb`:

```ruby
test "overrides has_risk to nil for items not applicable to property type" do
  # Set up an item with applicable_types = ["아파트"] but metadata says "단독주택"
  finance_item = InspectionItem.create!(
    code: "finance-003", tab: :profit_analysis, tab_position: 2,
    category: "자금&대출 분석",
    question: "등기부등본에 근저당 설정 이력이 있습니까?",
    applicable_types: ["아파트"],
    yes_means_safe: true
  )

  response_with_detached = @response.deep_dup
  response_with_detached["metadata"]["property_type"] = "단독주택"
  response_with_detached["results"]["finance-003"] = {
    "has_risk" => false, "confidence" => "high",
    "reasoning" => "근저당 설정 이력이 확인됩니다."
  }

  items_with_finance = @items.to_a + [finance_item]

  Inspection::InspectionResultMapper.call(
    response: response_with_detached, property: @property, user: @user, items: items_with_finance
  )

  result = InspectionResult.find_by(property: @property, inspection_item: finance_item, user: @user)
  assert_nil result.has_risk, "should override to nil for non-applicable property type"
  assert_equal "none", result.evidence["confidence"]
  assert_includes result.evidence["reasoning"], "단독주택"
ensure
  finance_item&.destroy
end
```

- [ ] **Step 3: Run test to verify it fails**

Run: `bin/rails test test/services/inspection/inspection_result_mapper_test.rb -n "test_overrides_has_risk_to_nil_for_items_not_applicable_to_property_type"`
Expected: FAIL — has_risk is not nil

- [ ] **Step 4: Add post-processing validation**

In `app/services/inspection/inspection_result_mapper.rb`, add type validation inside the mapping loop, after the `has_risk` assignment but before `result.save!`:

```ruby
        # Server-side: override AI result for non-applicable property types
        if @property_type.present? && item.applicable_types.present? && !item.applicable_for?(@property_type)
          original_reasoning = ai_result&.dig("reasoning")
          override_reasoning = "해당 물건은 #{@property_type}이므로 이 항목(#{item.applicable_types.join('·')} 전용)은 직접 확인이 필요합니다."
          override_reasoning += " AI 의견: #{original_reasoning}" if original_reasoning.present?

          result.assign_attributes(
            source_type: "ai",
            has_risk: nil,
            evidence: {
              source_label: "AI 분석 (참고)",
              confidence: "none",
              reasoning: override_reasoning
            }
          )
        end
```

Place this block right before `result.save!`.

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/services/inspection/inspection_result_mapper_test.rb -n "test_overrides_has_risk_to_nil_for_items_not_applicable_to_property_type"`
Expected: PASS

- [ ] **Step 6: Run full mapper test suite**

Run: `bin/rails test test/services/inspection/inspection_result_mapper_test.rb`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add app/services/inspection/inspection_result_mapper.rb test/services/inspection/inspection_result_mapper_test.rb
git commit -m "feat: server-side validation of applicable_types against property_type in mapper"
```

---

### Task 9: Update fixtures and run full test suite

**Files:**
- Modify: `test/fixtures/inspection_items.yml` (add applicable_types to relevant fixtures)

- [ ] **Step 1: Update fixtures with applicable_types where needed**

Add `applicable_types` to the `market_006` fixture in `test/fixtures/inspection_items.yml`:

```yaml
market_006:
  code: "market-006"
  tab: 2
  tab_position: 10
  category: "시세·수익성 분석"
  question: "단독(나홀로) 건물이 아닌 단지형 아파트입니까?"
  description: "단지형 확인"
  logic: '{"yes": "단지형입니다.", "no": "나홀로 건물입니다."}'
  data_source_name: "수동 입력"
  priority: "상"
  yes_means_safe: true
```

Note: `market_006` does NOT get `applicable_types` — it applies to all property types. Only `finance-003`, `market-007`, `market-008` get `applicable_types` in the JSON seed.

- [ ] **Step 2: Run full test suite**

Run: `bin/rails test`
Expected: All PASS

- [ ] **Step 3: Run seed to apply all changes**

Run: `bin/rails db:seed`
Expected: No errors

- [ ] **Step 4: Run rubocop**

Run: `bin/rubocop`
Expected: No offenses

- [ ] **Step 5: Run brakeman**

Run: `bin/brakeman --quiet --no-pager`
Expected: No warnings

- [ ] **Step 6: Commit any remaining fixes**

```bash
git add -A
git commit -m "chore: update fixtures and verify full test suite passes"
```

---

## Summary of Changes

| Issue # | Root Cause | Fix |
|---------|-----------|-----|
| 1. 판정 근거 줄바꿈 없음 | CSS `whitespace` 미적용 | `whitespace-pre-line` 클래스 추가 (Task 1) |
| 2. 대항력 없는데 No 표시 | AI 프롬프트에 property_type 참조 규칙 없음 | 프롬프트 보강 (Task 5) |
| 3. 엘리베이터 질문 | 4층 미만 건물에도 질문 | 질문 변경 + 프롬프트 규칙 (Task 3, 5) |
| 4. 아파트 아닌데 Yes | AI가 metadata의 property_type 미참조 | 프롬프트 + 서버 보정 (Task 5, 8) |
| 5. "빌라의 방" 하드코딩 | 질문 텍스트에 "빌라" 고정 | "해당 건축물"로 변경 (Task 3) |
| 6. "빌라가 위치한" 하드코딩 | 질문 텍스트에 "빌라" 고정 | "해당 건축물"로 변경 (Task 3) |
| 7. 나홀로 건물 오판 | AI가 property_type 미참조 | 프롬프트 규칙 추가 (Task 5) |
| 8. 세대수 비율 — 아파트 전용 | 모든 물건에 적용 | `applicable_types` 추가 (Task 2, 3, 8) |
| 9. 신축 입주 — 아파트 전용 | 모든 물건에 적용 | `applicable_types` 추가 (Task 2, 3, 8) |
| 10. 근저당 은행 — 아파트 전용 | 모든 물건에 적용 | `applicable_types` 추가 + 텍스트 중립화 (Task 2, 3, 8) |
| 근거 부족 시 AI 의견 유실 | confidence=none → evidence=nil | reasoning 보존 (Task 6, 7) |
