# Inspection Evidence Display Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show users the actual data (field values, keyword match results, source documents) that drove each auto-selected checklist answer in the inspection screen.

**Architecture:** Add `evidence` JSON column to `inspection_results`. Modify each `DETECTION_RULES` lambda in `InspectionRunner` to return `{ has_risk:, evidence: }` hashes instead of booleans. Render evidence blocks in `InspectionItemComponent` below the Yes/No logic section.

**Tech Stack:** Rails 8.1, SQLite JSON column, ViewComponent, TailwindCSS, Minitest

**Spec:** `docs/superpowers/specs/2026-04-10-inspection-evidence-display-design.md`

---

### Task 1: Add `evidence` JSON column to `inspection_results`

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_evidence_to_inspection_results.rb`
- Modify: `db/schema.rb` (auto-generated)

- [ ] **Step 1: Generate migration**

Run:
```bash
bin/rails generate migration AddEvidenceToInspectionResults evidence:json
```

- [ ] **Step 2: Run migration**

Run:
```bash
bin/rails db:migrate
```
Expected: Migration succeeds, `db/schema.rb` updated with `t.json "evidence"` in the `inspection_results` table.

- [ ] **Step 3: Verify schema**

Run:
```bash
grep -A 20 'create_table "inspection_results"' db/schema.rb
```
Expected: `t.json "evidence"` appears in the column list.

- [ ] **Step 4: Commit**

```bash
git add db/migrate/*_add_evidence_to_inspection_results.rb db/schema.rb
git commit -m "feat: add evidence JSON column to inspection_results"
```

---

### Task 2: Update InspectionRunner — change `call` method to handle Hash returns

**Files:**
- Modify: `app/services/inspection_runner.rb:166-199` (the `call` method)
- Test: `test/services/inspection_runner_test.rb`

- [ ] **Step 1: Write failing test — evidence is stored for auto-detected field comparison rule**

Add to `test/services/inspection_runner_test.rb`:

```ruby
test "auto-detected result stores evidence with field data" do
  InspectionRunner.call(property: @safe_property, user: @user)
  result = find_result(@safe_property, "property-006")
  return unless result
  assert_equal "auto", result.source_type
  assert_not_nil result.evidence, "auto result should have evidence"
  assert_equal "법원경매 물건정보", result.evidence["source_label"]
  assert_kind_of Array, result.evidence["fields"]
  field = result.evidence["fields"].find { |f| f["label"] == "물건종류" }
  assert_not_nil field
  assert_equal "아파트", field["value"]
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/inspection_runner_test.rb -n "test_auto-detected_result_stores_evidence_with_field_data"`
Expected: FAIL — `result.evidence` is nil because rules still return booleans.

- [ ] **Step 3: Write failing test — evidence is stored for keyword matching rule**

Add to `test/services/inspection_runner_test.rb`:

```ruby
test "auto-detected result stores evidence with keyword data" do
  InspectionRunner.call(property: @safe_property, user: @user)
  result = find_result(@safe_property, "rights-020")
  return unless result
  assert_equal "auto", result.source_type
  assert_not_nil result.evidence
  assert_equal "비고, 물건명세서, 현황조사서", result.evidence["source_label"]
  assert_kind_of Hash, result.evidence["keywords"]
  assert_includes result.evidence["keywords"]["searched"], "유치권"
  assert_equal false, result.evidence["keywords"]["found"]
end
```

- [ ] **Step 4: Run test to verify it fails**

Run: `bin/rails test test/services/inspection_runner_test.rb -n "test_auto-detected_result_stores_evidence_with_keyword_data"`
Expected: FAIL — same reason.

- [ ] **Step 5: Update `call` method to handle Hash returns**

In `app/services/inspection_runner.rb`, replace the `call` method (lines 166-199):

```ruby
def call
  # Eager load associations to avoid N+1
  @property.sale_detail
  @property.appraisal_points.load

  InspectionItem.ordered.map do |item|
    result = @property.inspection_results.find_or_initialize_by(inspection_item: item, user: @user)

    rule = DETECTION_RULES[item.code]
    if rule.nil?
      unless user_manually_answered?(result)
        result.assign_attributes(source_type: nil, has_risk: nil, evidence: nil)
      end
    else
      detected = begin
        rule.call(@property)
      rescue
        nil
      end
      if detected.nil?
        unless user_manually_answered?(result)
          result.assign_attributes(source_type: nil, has_risk: nil, evidence: nil)
        end
      elsif detected.is_a?(Hash)
        result.assign_attributes(
          source_type: "auto",
          has_risk: detected[:has_risk],
          evidence: detected[:evidence]
        )
      end
    end

    result.save!
    result
  end
end
```

- [ ] **Step 6: Run all existing tests to verify nothing is broken**

Run: `bin/rails test test/services/inspection_runner_test.rb`
Expected: All existing tests FAIL because rules still return booleans but `call` now only handles Hashes. This is expected — we'll update the rules in the next tasks.

- [ ] **Step 7: Commit the `call` method change and new tests**

```bash
git add app/services/inspection_runner.rb test/services/inspection_runner_test.rb
git commit -m "feat: update InspectionRunner#call to handle Hash returns with evidence"
```

---

### Task 3: Convert Auto Grade DETECTION_RULES to return Hash with evidence

**Files:**
- Modify: `app/services/inspection_runner.rb:9-95` (Auto Grade rules in DETECTION_RULES)
- Test: `test/services/inspection_runner_test.rb`

- [ ] **Step 1: Convert all Auto Grade rules**

Replace lines 9-95 in `app/services/inspection_runner.rb` (from `DETECTION_RULES = {` through the end of `market-012`):

```ruby
DETECTION_RULES = {
  # ============================================================
  # Auto grade — court_auction fields fully determine yes/no
  # ============================================================

  # rights-002: 소멸되지 않는 인수 권리 유무
  "rights-002" => ->(p) {
    text = p.sale_detail&.non_extinguished_rights
    has_risk = if p.sale_detail.nil?
      false
    else
      text.present?
    end
    {
      has_risk: has_risk,
      evidence: {
        source_label: "매각물건명세서",
        fields: [{ label: "소멸되지 않는 권리", value: text.present? ? text : "없음" }]
      }
    }
  },

  # rights-011: 유치권·법정지상권 기재
  "rights-011" => ->(p) {
    combined = [
      p.remarks,
      p.sale_detail&.specification_remarks,
      p.sale_detail&.goods_remarks,
      p.sale_detail&.superficies_details
    ].compact.join("\n")
    found = combined.present? && (combined.match?(LIEN_PATTERN) || combined.match?(SUPERFICIES_PATTERN))
    {
      has_risk: found,
      evidence: {
        source_label: "비고, 물건명세서, 현황조사서",
        keywords: { searched: ["유치권", "법정지상권"], found: found }
      }
    }
  },

  # property-002: 벽체 구분·불법 구조변경
  "property-002" => ->(p) {
    combined = [
      p.remarks,
      p.sale_detail&.specification_remarks,
      p.sale_detail&.goods_remarks
    ].compact.join("\n")
    found = combined.present? && combined.match?(WALL_PATTERN)
    {
      has_risk: found ? true : false,
      evidence: {
        source_label: "비고, 물건명세서, 현황조사서",
        keywords: { searched: ["벽체", "구조변경", "불법증축", "불법개축"], found: found ? true : false }
      }
    }
  },

  # rights-019: 토지·건물 일체 매각
  "rights-019" => ->(p) {
    return nil if p.property_type != "아파트" && p.land_category.nil?
    has_risk = if p.property_type == "아파트"
      false
    else
      p.land_category != "전유"
    end
    fields = [{ label: "물건종류", value: p.property_type }]
    fields << { label: "토지구분", value: p.land_category } if p.land_category.present?
    {
      has_risk: has_risk,
      evidence: {
        source_label: "법원경매 물건정보",
        fields: fields
      }
    }
  },

  # rights-020: 유치권 신고
  "rights-020" => ->(p) {
    combined = [
      p.remarks,
      p.sale_detail&.specification_remarks,
      p.sale_detail&.goods_remarks
    ].compact.join("\n")
    found = combined.present? && combined.match?(LIEN_PATTERN)
    {
      has_risk: found ? true : false,
      evidence: {
        source_label: "비고, 물건명세서, 현황조사서",
        keywords: { searched: ["유치권"], found: found ? true : false }
      }
    }
  },

  # property-006: 물건 종류 아파트 여부
  "property-006" => ->(p) {
    {
      has_risk: p.property_type != "아파트",
      evidence: {
        source_label: "법원경매 물건정보",
        fields: [{ label: "물건종류", value: p.property_type }]
      }
    }
  },

  # resale-003: 지상층 위치
  "resale-003" => ->(p) {
    floor = p.building_detail
    return nil if floor.blank?
    {
      has_risk: floor.match?(/지하|반지하/) && !floor.match?(/지상/),
      evidence: {
        source_label: "법원경매 물건정보",
        fields: [{ label: "층 정보", value: floor }]
      }
    }
  },

  # property-001: 비지분 물건
  "property-001" => ->(p) {
    return nil if p.sale_detail.nil?
    share = p.sale_detail.share_description
    {
      has_risk: share.present?,
      evidence: {
        source_label: "매각물건명세서",
        fields: [{ label: "지분 내역", value: share.present? ? share : "없음" }]
      }
    }
  },

  # tax-006: 전용면적 85㎡ 미만
  "tax-006" => ->(p) {
    area = p.exclusive_area
    return nil if area.nil? || area.zero?
    {
      has_risk: area >= 85,
      evidence: {
        source_label: "법원경매 물건정보",
        fields: [{ label: "전용면적", value: "#{area}㎡" }]
      }
    }
  },

  # market-012: 조회수 500회 미만
  "market-012" => ->(p) {
    count = p.view_count || 0
    {
      has_risk: count >= 500,
      evidence: {
        source_label: "법원경매 물건정보",
        fields: [{ label: "조회수", value: "#{count}회" }]
      }
    }
  },
```

- [ ] **Step 2: Run all tests**

Run: `bin/rails test test/services/inspection_runner_test.rb`
Expected: All Auto Grade tests pass. Partial Grade tests still fail (those rules still return booleans/nil).

- [ ] **Step 3: Commit**

```bash
git add app/services/inspection_runner.rb
git commit -m "feat: convert Auto Grade DETECTION_RULES to return evidence hashes"
```

---

### Task 4: Convert Partial Grade DETECTION_RULES to return Hash with evidence

**Files:**
- Modify: `app/services/inspection_runner.rb:100-155` (Partial Grade rules)
- Test: `test/services/inspection_runner_test.rb`

- [ ] **Step 1: Write failing test — partial grade keyword rule stores evidence**

Add to `test/services/inspection_runner_test.rb`:

```ruby
test "partial grade keyword rule stores evidence when risk detected" do
  InspectionRunner.call(property: @basement_villa, user: @user)
  result = find_result(@basement_villa, "rights-005")
  return unless result
  assert_equal "auto", result.source_type
  assert_not_nil result.evidence
  assert_equal "물건명세서, 감정평가서", result.evidence["source_label"]
  assert_includes result.evidence["keywords"]["searched"], "무허가"
  assert_equal true, result.evidence["keywords"]["found"]
end

test "partial grade field rule stores evidence when risk detected" do
  property = @safe_property
  property.update!(status: "취하")
  InspectionRunner.call(property: property, user: @user)
  result = find_result(property, "bidding-001")
  return unless result
  assert_equal "auto", result.source_type
  assert_not_nil result.evidence
  assert_equal "법원경매 물건정보", result.evidence["source_label"]
  field = result.evidence["fields"].find { |f| f["label"] == "진행상태" }
  assert_equal "취하", field["value"]
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/inspection_runner_test.rb -n "/partial grade.*stores evidence/"`
Expected: FAIL — partial rules still return booleans.

- [ ] **Step 3: Convert all Partial Grade rules**

Replace the Partial Grade section in `app/services/inspection_runner.rb`:

```ruby
  # ============================================================
  # Partial grade — hints or partial conditions
  # ============================================================

  # rights-005: 사용 승인 정상 건물 (risk detection only)
  "rights-005" => ->(p) {
    combined = [
      p.sale_detail&.specification_remarks,
      p.sale_detail&.goods_remarks
    ].compact.join("\n")
    appraisal_text = p.appraisal_points.map(&:content).compact.join("\n")
    all_text = [ combined, appraisal_text ].reject(&:blank?).join("\n")
    return nil if all_text.blank?
    found = all_text.match?(USE_APPROVAL_PATTERN)
    return nil unless found
    {
      has_risk: true,
      evidence: {
        source_label: "물건명세서, 감정평가서",
        keywords: { searched: ["무허가", "미등기", "사용승인 미", "허가 미취득"], found: true }
      }
    }
  },

  # inspect-001: 감정평가서 특이사항 (keyword detection)
  "inspect-001" => ->(p) {
    text = p.appraisal_points.map(&:content).compact.join("\n")
    return nil if text.blank?
    found = text.match?(APPRAISAL_RISK_PATTERN)
    return nil unless found
    {
      has_risk: true,
      evidence: {
        source_label: "감정평가서",
        keywords: { searched: ["불법증축", "무허가", "환경오염", "면적불일치", "균열", "누수", "침수"], found: true }
      }
    }
  },

  # inspect-004: 오피스텔 주거/업무 용도
  "inspect-004" => ->(p) {
    nil
  },

  # market-006: 단지형 건물 여부
  "market-006" => ->(p) {
    if p.property_type == "아파트" && p.building_name.present?
      {
        has_risk: false,
        evidence: {
          source_label: "법원경매 물건정보",
          fields: [
            { label: "물건종류", value: p.property_type },
            { label: "건물명", value: p.building_name }
          ]
        }
      }
    else
      nil
    end
  },

  # rights-021: 전세사기 피해자 우선매수권
  "rights-021" => ->(p) {
    combined = [
      p.special_conditions_code,
      p.remarks,
      p.sale_detail&.specification_remarks
    ].compact.join("\n")
    return nil if combined.blank?
    found = combined.match?(FRAUD_PATTERN)
    return nil unless found
    {
      has_risk: true,
      evidence: {
        source_label: "특별매각조건, 비고, 물건명세서",
        keywords: { searched: ["우선매수", "전세사기", "특별법"], found: true }
      }
    }
  },

  # bidding-001: 경매 진행 상태 확인
  "bidding-001" => ->(p) {
    return nil if p.status.blank?
    return nil if p.status == "진행중"
    {
      has_risk: true,
      evidence: {
        source_label: "법원경매 물건정보",
        fields: [{ label: "진행상태", value: p.status }]
      }
    }
  },

  # bidding-003: 입찰 보증금 준비
  "bidding-003" => ->(p) {
    nil
  }
}.freeze
```

- [ ] **Step 4: Run all InspectionRunner tests**

Run: `bin/rails test test/services/inspection_runner_test.rb`
Expected: ALL tests pass (both existing and new evidence tests).

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection_runner.rb test/services/inspection_runner_test.rb
git commit -m "feat: convert Partial Grade DETECTION_RULES to return evidence hashes"
```

---

### Task 5: Add evidence rendering to InspectionItemComponent

**Files:**
- Modify: `app/components/inspection_item_component.rb`
- Modify: `app/components/inspection_item_component.html.erb`
- Test: `test/components/inspection_item_component_test.rb`

- [ ] **Step 1: Write failing test — evidence block renders for field comparison**

Add to `test/components/inspection_item_component_test.rb`:

```ruby
test "renders evidence block with field data for auto result" do
  result = inspection_results(:safe_apartment_rights_002)
  result.update!(evidence: {
    "source_label" => "법원경매 물건정보",
    "fields" => [{ "label" => "물건종류", "value" => "아파트" }]
  })
  render_inline(InspectionItemComponent.new(result: result))

  assert_selector "[data-evidence]"
  assert_text "판정 근거"
  assert_text "법원경매 물건정보"
  assert_text "물건종류"
  assert_text "아파트"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/inspection_item_component_test.rb -n "test_renders_evidence_block_with_field_data_for_auto_result"`
Expected: FAIL — no `[data-evidence]` selector exists yet.

- [ ] **Step 3: Write failing test — evidence block renders for keyword matching**

Add to `test/components/inspection_item_component_test.rb`:

```ruby
test "renders evidence block with keyword data for auto result" do
  result = inspection_results(:safe_apartment_rights_011)
  result.update!(evidence: {
    "source_label" => "비고, 물건명세서, 현황조사서",
    "keywords" => { "searched" => ["유치권", "법정지상권"], "found" => false }
  })
  render_inline(InspectionItemComponent.new(result: result))

  assert_selector "[data-evidence]"
  assert_text "판정 근거"
  assert_text "비고, 물건명세서, 현황조사서"
  assert_text "유치권"
  assert_text "해당 없음"
end
```

- [ ] **Step 4: Write failing test — evidence block absent for manual result**

Add to `test/components/inspection_item_component_test.rb`:

```ruby
test "does not render evidence block for manual result" do
  result = inspection_results(:manual_risk)
  render_inline(InspectionItemComponent.new(result: result))

  refute_selector "[data-evidence]"
end
```

- [ ] **Step 5: Write failing test — keyword found shows "발견" text**

Add to `test/components/inspection_item_component_test.rb`:

```ruby
test "renders keyword found state with 발견 text" do
  result = inspection_results(:risky_villa_rights_011)
  result.update!(evidence: {
    "source_label" => "비고, 물건명세서, 현황조사서",
    "keywords" => { "searched" => ["유치권", "법정지상권"], "found" => true }
  })
  render_inline(InspectionItemComponent.new(result: result))

  assert_selector "[data-evidence]"
  assert_text "발견"
end
```

- [ ] **Step 6: Run all new tests to verify they fail**

Run: `bin/rails test test/components/inspection_item_component_test.rb -n "/evidence/"`
Expected: All 4 new tests FAIL.

- [ ] **Step 7: Add helper methods to InspectionItemComponent**

Add to `app/components/inspection_item_component.rb` inside the `private` block:

```ruby
def evidence_present?
  auto_source? && @result.evidence.present?
end

def evidence
  @result.evidence
end

def evidence_border_classes
  if @result.has_risk
    "border-l-red-500 bg-red-500/5 dark:bg-red-500/10"
  else
    "border-l-indigo-500 bg-indigo-500/5 dark:bg-indigo-500/10"
  end
end

def evidence_header_classes
  if @result.has_risk
    "text-red-400"
  else
    "text-indigo-400"
  end
end

def evidence_label_classes
  if @result.has_risk
    "text-red-300 dark:text-red-400"
  else
    "text-indigo-300 dark:text-indigo-400"
  end
end

def evidence_value_classes
  "text-slate-200 dark:text-slate-200 font-medium"
end

def keyword_result_classes
  if @result.has_risk
    "text-red-400 font-semibold"
  else
    "text-green-400"
  end
end
```

- [ ] **Step 8: Add evidence block to the ERB template**

In `app/components/inspection_item_component.html.erb`, add the following block after the logic Yes/No section (after the `<% end %>` that closes `<% if logic_present? %>`), before the edit mode section:

```erb
<% if evidence_present? %>
  <div class="mt-2.5 rounded-r-md border-l-3 p-2 px-3 text-xs <%= evidence_border_classes %>"
       data-evidence>
    <div class="font-semibold mb-1 <%= evidence_header_classes %>">📋 판정 근거 · <%= evidence["source_label"] %></div>
    <% if evidence["fields"].present? %>
      <% evidence["fields"].each do |field| %>
        <div class="<%= evidence_label_classes %>"><%= field["label"] %>: <span class="<%= evidence_value_classes %>"><%= field["value"] %></span></div>
      <% end %>
    <% end %>
    <% if evidence["keywords"].present? %>
      <div class="<%= evidence_label_classes %>">매칭 키워드: <span class="text-slate-300 dark:text-slate-300"><%= evidence["keywords"]["searched"].map { |k| "\"#{k}\"" }.join(", ") %></span></div>
      <div class="mt-0.5 <%= evidence_label_classes %>">결과: <span class="<%= keyword_result_classes %>"><%= evidence["keywords"]["found"] ? "발견" : "해당 없음" %></span></div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 9: Run all component tests**

Run: `bin/rails test test/components/inspection_item_component_test.rb`
Expected: ALL tests pass (both existing and new evidence tests).

- [ ] **Step 10: Commit**

```bash
git add app/components/inspection_item_component.rb app/components/inspection_item_component.html.erb test/components/inspection_item_component_test.rb
git commit -m "feat: render evidence block in InspectionItemComponent"
```

---

### Task 6: Update fixtures and integration test

**Files:**
- Modify: `test/fixtures/inspection_results.yml`
- Modify: `test/integration/property_inspection_flow_test.rb`

- [ ] **Step 1: Add evidence to fixtures**

Update `test/fixtures/inspection_results.yml`:

```yaml
safe_apartment_rights_002:
  property: safe_apartment
  inspection_item: rights_002
  user: guest
  source_type: 0
  has_risk: false
  evidence: '{"source_label":"매각물건명세서","fields":[{"label":"소멸되지 않는 권리","value":"없음"}]}'

safe_apartment_rights_011:
  property: safe_apartment
  inspection_item: rights_011
  user: guest
  source_type: 0
  has_risk: false
  evidence: '{"source_label":"비고, 물건명세서, 현황조사서","keywords":{"searched":["유치권","법정지상권"],"found":false}}'

risky_villa_rights_011:
  property: risky_villa
  inspection_item: rights_011
  user: guest
  source_type: 0
  has_risk: true
  resolvable: false
  evidence: '{"source_label":"비고, 물건명세서, 현황조사서","keywords":{"searched":["유치권","법정지상권"],"found":true}}'

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

- [ ] **Step 2: Add integration test for evidence persistence through full flow**

Add to `test/integration/property_inspection_flow_test.rb`:

```ruby
test "inspection flow stores evidence for auto-detected results" do
  post property_inspections_start_url(@property)

  auto_results = @property.inspection_results
    .where(user: @user, source_type: "auto")
    .where.not(evidence: nil)

  assert auto_results.any?, "At least one auto result should have evidence"

  auto_results.each do |result|
    assert_not_nil result.evidence["source_label"],
      "evidence for #{result.inspection_item.code} should have source_label"
    has_fields = result.evidence["fields"].present?
    has_keywords = result.evidence["keywords"].present?
    assert has_fields || has_keywords,
      "evidence for #{result.inspection_item.code} should have fields or keywords"
  end
end
```

- [ ] **Step 3: Run all tests**

Run: `bin/rails test test/integration/property_inspection_flow_test.rb test/components/inspection_item_component_test.rb test/services/inspection_runner_test.rb`
Expected: ALL tests pass.

- [ ] **Step 4: Run full test suite**

Run: `bin/rails test`
Expected: ALL tests pass — no regressions.

- [ ] **Step 5: Commit**

```bash
git add test/fixtures/inspection_results.yml test/integration/property_inspection_flow_test.rb
git commit -m "feat: update fixtures with evidence and add integration test"
```

---

### Task 7: Run linting and security checks

**Files:** None (verification only)

- [ ] **Step 1: Run rubocop**

Run: `bin/rubocop`
Expected: No new offenses. If any, fix them.

- [ ] **Step 2: Run brakeman**

Run: `bin/brakeman --quiet --no-pager`
Expected: No new warnings.

- [ ] **Step 3: Fix any issues and commit if needed**

If rubocop or brakeman flags issues, fix and commit:
```bash
git add -A
git commit -m "fix: address rubocop/brakeman findings"
```
