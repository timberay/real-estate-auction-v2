# Yes-Means-Safe Polarity Flag Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix checklist items where "Yes" means danger but the UI incorrectly displays green (safe) colors, by adding a per-question `yes_means_safe` boolean flag.

**Architecture:** Add a `yes_means_safe` column to `inspection_items` (default `true`). The flag controls only the display mapping between Yes/No labels and safe/danger colors. The `has_risk` boolean semantics (true = danger) remain unchanged. All color logic (component, template, Stimulus controller) reads this flag to determine which answer gets green vs red highlighting.

**Tech Stack:** Rails 8.1, Minitest, ViewComponent, Stimulus (JS), TailwindCSS, SQLite

**Spec:** `docs/superpowers/specs/2026-04-08-yes-means-safe-polarity-flag-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `db/migrate/XXXXXX_add_yes_means_safe_to_inspection_items.rb` | Create | Migration: add boolean column |
| `app/models/inspection_item.rb` | No change | Column is a plain boolean, no declaration needed |
| `db/seeds/checklist_items_summary.json` | Modify | Add `"yes_means_safe": false` to 15 items |
| `db/seeds.rb` | Modify | Map `yes_means_safe` from JSON to model |
| `app/components/inspection_item_component.rb` | Modify | Update `selected_answer`, add `logic_highlight_classes` helper |
| `app/components/inspection_item_component.html.erb` | Modify | Use dynamic color classes, flip radio button values |
| `app/javascript/controllers/inspection_item_controller.js` | Modify | Add `yesMeansSafe` value, update `#updateLogicHighlight` |
| `test/fixtures/inspection_items.yml` | Modify | Add `yes_means_safe` to fixtures |
| `test/models/inspection_item_test.rb` | Modify | Test default value |
| `test/components/inspection_item_component_test.rb` | Modify | Test both polarities |

---

### Task 1: Migration — Add `yes_means_safe` Column

**Files:**
- Create: `db/migrate/XXXXXX_add_yes_means_safe_to_inspection_items.rb`

- [ ] **Step 1: Generate migration**

Run:
```bash
bin/rails generate migration AddYesMeansSafeToInspectionItems yes_means_safe:boolean
```

- [ ] **Step 2: Edit migration to set null constraint and default**

Open the generated file and ensure it matches:

```ruby
class AddYesMeansSafeToInspectionItems < ActiveRecord::Migration[8.1]
  def change
    add_column :inspection_items, :yes_means_safe, :boolean, null: false, default: true
  end
end
```

- [ ] **Step 3: Run migration**

Run: `bin/rails db:migrate`

Expected: Migration succeeds, all existing rows get `yes_means_safe: true`.

- [ ] **Step 4: Verify schema**

Run: `bin/rails runner "puts InspectionItem.column_names.include?('yes_means_safe')"`

Expected: `true`

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*_add_yes_means_safe_to_inspection_items.rb db/schema.rb
git commit -m "feat(db): add yes_means_safe boolean column to inspection_items"
```

---

### Task 2: Seed Data — Add `yes_means_safe` to JSON and Loader

**Files:**
- Modify: `db/seeds/checklist_items_summary.json`
- Modify: `db/seeds.rb`

- [ ] **Step 1: Add `yes_means_safe: false` to 15 items in seed JSON**

For each of these 15 item IDs, add `"yes_means_safe": false` as a top-level key (after `"priority"`):

1. `rights-011`
2. `rights-003`
3. `rights-010`
4. `rights-016`
5. `rights-020`
6. `property-002`
7. `rights-001`
8. `rights-004`
9. `rights-007`
10. `rights-008`
11. `rights-012`
12. `rights-022`
13. `rights-021`
14. `inspect-001`
15. `tax-005`

Example for `rights-011` (line ~26 in JSON):

```json
{
  "id": "rights-011",
  "tab": "매각물건명세서",
  "tab_position": 2,
  "category": "권리분석",
  "question": "매각물건명세서 비고란에 유치권 또는 법정지상권 기재가 있습니까?",
  "description": "...",
  "logic": { "yes": "...", "no": "..." },
  "data_source": [...],
  "priority": "상",
  "yes_means_safe": false
}
```

All other items do NOT need `yes_means_safe` — the DB default of `true` handles them.

- [ ] **Step 2: Update seed loader to map `yes_means_safe`**

In `db/seeds.rb`, find the `item.assign_attributes(...)` block (around line 81-92) and add `yes_means_safe`:

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
    yes_means_safe: attrs.fetch("yes_means_safe", true)
  )
```

Note: `attrs.fetch("yes_means_safe", true)` defaults to `true` for items that don't have the key in JSON.

- [ ] **Step 3: Run seed and verify**

Run: `bin/rails db:seed`

Then verify:

```bash
bin/rails runner "puts InspectionItem.where(yes_means_safe: false).pluck(:code).sort.join(', ')"
```

Expected output (15 codes, alphabetically):
```
inspect-001, property-002, rights-001, rights-003, rights-004, rights-007, rights-008, rights-010, rights-011, rights-012, rights-016, rights-020, rights-021, rights-022, tax-005
```

- [ ] **Step 4: Commit**

```bash
git add db/seeds/checklist_items_summary.json db/seeds.rb
git commit -m "feat(seeds): add yes_means_safe flag to 15 inverted-polarity questions"
```

---

### Task 3: Test Fixtures — Add `yes_means_safe` Field

**Files:**
- Modify: `test/fixtures/inspection_items.yml`

- [ ] **Step 1: Add `yes_means_safe: false` to inverted fixtures**

The fixtures `rights_011` and `rights_001` are inverted-polarity questions. Add the field:

```yaml
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
  yes_means_safe: true

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
  yes_means_safe: false

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
  yes_means_safe: false

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
  yes_means_safe: false

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
  yes_means_safe: false

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
  yes_means_safe: true

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
  yes_means_safe: false
```

Note: `rights_002` and `inspect_007` get `yes_means_safe: true`. All others (`rights_011`, `rights_001`, `property_004`, `property_001`, `manual_001`) get `yes_means_safe: false` because their questions are phrased so that "Yes" indicates danger.

- [ ] **Step 2: Run existing tests to make sure fixtures load**

Run: `bin/rails test test/models/inspection_item_test.rb`

Expected: All pass (no behavioral change yet).

- [ ] **Step 3: Commit**

```bash
git add test/fixtures/inspection_items.yml
git commit -m "test(fixtures): add yes_means_safe field to inspection_item fixtures"
```

---

### Task 4: Model Test — Verify Default Value

**Files:**
- Modify: `test/models/inspection_item_test.rb`

- [ ] **Step 1: Write failing test for `yes_means_safe` default**

Add to `test/models/inspection_item_test.rb`:

```ruby
test "yes_means_safe defaults to true" do
  item = InspectionItem.new(
    code: "default-test",
    tab: "sale_document",
    tab_position: 1,
    category: "권리분석",
    question: "기본값 테스트?",
    priority: "상"
  )
  assert_equal true, item.yes_means_safe
end

test "yes_means_safe can be set to false" do
  item = InspectionItem.new(
    code: "inverted-test",
    tab: "sale_document",
    tab_position: 1,
    category: "권리분석",
    question: "반전 테스트?",
    priority: "상",
    yes_means_safe: false
  )
  assert_equal false, item.yes_means_safe
end
```

- [ ] **Step 2: Run test to verify it passes**

Run: `bin/rails test test/models/inspection_item_test.rb`

Expected: All tests pass (the migration already added the column with default).

- [ ] **Step 3: Commit**

```bash
git add test/models/inspection_item_test.rb
git commit -m "test(model): add yes_means_safe default and assignment tests"
```

---

### Task 5: Component Logic — Update `selected_answer` and Add Color Helpers

**Files:**
- Modify: `app/components/inspection_item_component.rb`
- Test: `test/components/inspection_item_component_test.rb`

- [ ] **Step 1: Write failing tests for inverted polarity**

Add these tests to `test/components/inspection_item_component_test.rb`:

```ruby
# --- Inverted polarity (yes_means_safe: false) tests ---

test "inverted polarity: highlights YES when has_risk is true" do
  result = inspection_results(:risky_villa_rights_011)
  assert_equal true, result.has_risk
  assert_equal false, result.inspection_item.yes_means_safe
  render_inline(InspectionItemComponent.new(result: result))

  assert_selector "[data-logic-selected='yes']"
  refute_selector "[data-logic-selected='no']"
end

test "inverted polarity: highlights NO when has_risk is false" do
  result = inspection_results(:safe_apartment_rights_011)
  assert_equal false, result.has_risk
  assert_equal false, result.inspection_item.yes_means_safe
  render_inline(InspectionItemComponent.new(result: result))

  assert_selector "[data-logic-selected='no']"
  refute_selector "[data-logic-selected='yes']"
end

test "inverted polarity: YES row uses red (danger) classes when selected" do
  result = inspection_results(:risky_villa_rights_011)
  render_inline(InspectionItemComponent.new(result: result))

  yes_row = page.find("[data-inspection-item-target='logicYes']")
  assert_includes yes_row[:class], "bg-red-50"
  assert_includes yes_row[:class], "text-red-800"
end

test "inverted polarity: NO row uses green (safe) classes when selected" do
  result = inspection_results(:safe_apartment_rights_011)
  render_inline(InspectionItemComponent.new(result: result))

  no_row = page.find("[data-inspection-item-target='logicNo']")
  assert_includes no_row[:class], "bg-green-50"
  assert_includes no_row[:class], "text-green-800"
end

test "normal polarity: YES row uses green (safe) classes when selected" do
  result = inspection_results(:safe_apartment_rights_002)
  assert_equal true, result.inspection_item.yes_means_safe
  render_inline(InspectionItemComponent.new(result: result))

  yes_row = page.find("[data-inspection-item-target='logicYes']")
  assert_includes yes_row[:class], "bg-green-50"
  assert_includes yes_row[:class], "text-green-800"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/inspection_item_component_test.rb`

Expected: New tests FAIL because `selected_answer` still uses the old hardcoded mapping.

- [ ] **Step 3: Update `selected_answer` in component**

In `app/components/inspection_item_component.rb`, replace the `selected_answer` method (lines 57-59):

```ruby
def selected_answer
  return nil if @result.has_risk.nil?
  if @item.yes_means_safe?
    @result.has_risk ? "no" : "yes"
  else
    @result.has_risk ? "yes" : "no"
  end
end
```

- [ ] **Step 4: Add color helper methods to component**

Add these private methods to `app/components/inspection_item_component.rb`:

```ruby
def logic_yes_classes
  return "" unless selected_answer
  if selected_answer == "yes"
    answer_means_safe = @item.yes_means_safe?
    answer_means_safe ? "bg-green-50 dark:bg-green-900/20 font-semibold text-green-800 dark:text-green-300" : "bg-red-50 dark:bg-red-900/20 font-semibold text-red-800 dark:text-red-300"
  else
    "text-slate-400 dark:text-slate-500"
  end
end

def logic_no_classes
  return "" unless selected_answer
  if selected_answer == "no"
    answer_means_safe = !@item.yes_means_safe?
    answer_means_safe ? "bg-green-50 dark:bg-green-900/20 font-semibold text-green-800 dark:text-green-300" : "bg-red-50 dark:bg-red-900/20 font-semibold text-red-800 dark:text-red-300"
  else
    "text-slate-400 dark:text-slate-500"
  end
end
```

- [ ] **Step 5: Update ERB template to use new helpers**

In `app/components/inspection_item_component.html.erb`, replace the logic section (lines 33-48):

```erb
<% if logic_present? %>
  <div class="mt-2 space-y-1 text-xs" data-logic-section>
    <div class="flex items-start gap-1.5 rounded px-2 py-1 <%= logic_yes_classes %>"
         data-inspection-item-target="logicYes"
         <% if selected_answer == 'yes' %>data-logic-selected="yes"<% end %>>
      <span class="shrink-0" data-inspection-item-target="logicYesIcon"><%= selected_answer == "yes" ? "✔" : "○" %></span>
      <span>Yes: <%= @item.logic["yes"] %></span>
    </div>
    <div class="flex items-start gap-1.5 rounded px-2 py-1 <%= logic_no_classes %>"
         data-inspection-item-target="logicNo"
         <% if selected_answer == 'no' %>data-logic-selected="no"<% end %>>
      <span class="shrink-0" data-inspection-item-target="logicNoIcon"><%= selected_answer == "no" ? "✔" : "○" %></span>
      <span>No: <%= @item.logic["no"] %></span>
    </div>
  </div>
<% end %>
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bin/rails test test/components/inspection_item_component_test.rb`

Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add app/components/inspection_item_component.rb app/components/inspection_item_component.html.erb test/components/inspection_item_component_test.rb
git commit -m "feat(component): support yes_means_safe polarity in logic highlight colors"
```

---

### Task 6: Template — Flip Radio Button Values Based on Polarity

**Files:**
- Modify: `app/components/inspection_item_component.html.erb`
- Modify: `app/components/inspection_item_component.rb`

- [ ] **Step 1: Add radio value helpers to component**

Add these private methods to `app/components/inspection_item_component.rb`:

```ruby
def yes_radio_value
  @item.yes_means_safe? ? "false" : "true"
end

def no_radio_value
  @item.yes_means_safe? ? "true" : "false"
end
```

- [ ] **Step 2: Update manual input radio buttons (show_manual_input? section)**

In `app/components/inspection_item_component.html.erb`, find the manual input section (around lines 114-136). Replace the radio button values:

```erb
<% if show_manual_input? %>
  <div class="mt-3 border-t border-slate-200 dark:border-slate-600 pt-3">
    <div class="flex items-center gap-4">
      <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
        <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", yes_radio_value, @result.has_risk == (yes_radio_value == "true"),
            data: { action: "change->inspection-item#toggleManualRisk" }, class: "mr-1.5" %> 예
      </label>
      <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
        <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", no_radio_value, @result.has_risk == (no_radio_value == "true"),
            data: { action: "change->inspection-item#toggleManualRisk" }, class: "mr-1.5" %> 아니오
      </label>
    </div>
    <div data-inspection-item-target="resolutionSection" class="<%= 'hidden' unless @result.has_risk %> mt-3 rounded-md border border-dashed border-yellow-400 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20 p-3">
      <p class="mb-2 text-xs font-medium text-yellow-800 dark:text-yellow-300">해결 가능 여부를 선택해주세요:</p>
      <div class="flex items-center gap-4">
        <label class="inline-flex items-center text-sm text-yellow-900 dark:text-yellow-200"><%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "true", @result.resolvable == true, class: "mr-1.5" %> 해결 가능</label>
        <label class="inline-flex items-center text-sm text-yellow-900 dark:text-yellow-200"><%= radio_button_tag "resolutions[#{@result.id}][resolvable]", "false", @result.resolvable == false, class: "mr-1.5" %> 해결 불가</label>
      </div>
      <%= text_field_tag "resolutions[#{@result.id}][resolution_note]", @result.resolution_note,
          placeholder: "해결 방안 메모",
          class: "mt-2 w-full h-10 rounded-md border border-yellow-300 dark:border-yellow-600 bg-white dark:bg-slate-700 px-3 text-sm placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500/20 transition-colors" %>
    </div>
  </div>
<% end %>
```

- [ ] **Step 3: Update edit mode radio buttons (show_edit_mode? section)**

In `app/components/inspection_item_component.html.erb`, find the edit mode section (around lines 52-95). Replace the radio button values and labels to reflect polarity:

```erb
    <div class="flex items-center gap-4">
      <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
        <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", yes_radio_value, @result.has_risk == (yes_radio_value == "true"),
            disabled: true,
            data: { action: "change->inspection-item#toggleManualRisk", inspection_item_target: "overrideRadio" },
            class: "mr-1.5" %> <%= @item.yes_means_safe? ? "Yes (안전)" : "Yes (위험)" %>
      </label>
      <label class="inline-flex items-center text-sm text-slate-700 dark:text-slate-200">
        <%= radio_button_tag "resolutions[#{@result.id}][has_risk]", no_radio_value, @result.has_risk == (no_radio_value == "true"),
            disabled: true,
            data: { action: "change->inspection-item#toggleManualRisk", inspection_item_target: "overrideRadio" },
            class: "mr-1.5" %> <%= @item.yes_means_safe? ? "No (위험)" : "No (안전)" %>
      </label>
    </div>
```

The rest of the edit section (override resolution, hidden field) stays the same.

- [ ] **Step 4: Run all component tests**

Run: `bin/rails test test/components/inspection_item_component_test.rb`

Expected: All PASS.

- [ ] **Step 5: Commit**

```bash
git add app/components/inspection_item_component.rb app/components/inspection_item_component.html.erb
git commit -m "feat(template): flip radio button values based on yes_means_safe polarity"
```

---

### Task 7: Stimulus Controller — Pass `yesMeansSafe` and Update Color Logic

**Files:**
- Modify: `app/components/inspection_item_component.html.erb`
- Modify: `app/javascript/controllers/inspection_item_controller.js`

- [ ] **Step 1: Add `yesMeansSafe` data attribute to root element**

In `app/components/inspection_item_component.html.erb`, add to the root div's data attributes (line 1-7):

Find:
```erb
data-inspection-item-original-badge-classes-value="<%= source_badge_classes %>">
```

Add after it (on the same div):
```erb
data-inspection-item-yes-means-safe-value="<%= @item.yes_means_safe? %>">
```

So the full opening div becomes:
```erb
<div class="rounded-lg border p-4 <%= risk_classes %>"
     data-controller="inspection-item"
     data-inspection-item-result-id-value="<%= @result.id %>"
     data-inspection-item-auto-value="<%= auto_source? %>"
     data-inspection-item-original-has-risk-value="<%= @result.has_risk.nil? ? '' : @result.has_risk %>"
     data-inspection-item-original-badge-text-value="<%= source_badge_text %>"
     data-inspection-item-original-badge-classes-value="<%= source_badge_classes %>"
     data-inspection-item-yes-means-safe-value="<%= @item.yes_means_safe? %>">
```

- [ ] **Step 2: Add `yesMeansSafe` to Stimulus static values**

In `app/javascript/controllers/inspection_item_controller.js`, update the `static values` declaration (line 21):

```javascript
static values = { resultId: Number, auto: Boolean, originalHasRisk: String, originalBadgeText: String, originalBadgeClasses: String, yesMeansSafe: Boolean }
```

- [ ] **Step 3: Update `#updateLogicHighlight` to respect polarity**

Replace the `#updateLogicHighlight` method (lines 118-145) with:

```javascript
#updateLogicHighlight(hasRisk) {
  if (!this.hasLogicYesTarget || !this.hasLogicNoTarget) return

  const yesEl = this.logicYesTarget
  const noEl = this.logicNoTarget
  const yesMeansSafe = this.yesMeansSafeValue

  // Determine which answer is selected based on polarity
  const yesSelected = yesMeansSafe ? !hasRisk : hasRisk
  const safeClasses = ["bg-green-50", "dark:bg-green-900/20", "font-semibold", "text-green-800", "dark:text-green-300"]
  const dangerClasses = ["bg-red-50", "dark:bg-red-900/20", "font-semibold", "text-red-800", "dark:text-red-300"]

  // Reset both rows
  yesEl.classList.remove(...ALL_LOGIC_CLASSES)
  noEl.classList.remove(...ALL_LOGIC_CLASSES)
  yesEl.removeAttribute("data-logic-selected")
  noEl.removeAttribute("data-logic-selected")

  if (yesSelected) {
    // Yes is the selected answer
    const yesColor = yesMeansSafe ? safeClasses : dangerClasses
    yesEl.classList.add(...yesColor)
    yesEl.setAttribute("data-logic-selected", "yes")
    noEl.classList.add(...LOGIC_DIMMED)
    this.logicYesIconTarget.textContent = "✔"
    this.logicNoIconTarget.textContent = "○"
  } else {
    // No is the selected answer
    const noColor = yesMeansSafe ? dangerClasses : safeClasses
    noEl.classList.add(...noColor)
    noEl.setAttribute("data-logic-selected", "no")
    yesEl.classList.add(...LOGIC_DIMMED)
    this.logicNoIconTarget.textContent = "✔"
    this.logicYesIconTarget.textContent = "○"
  }
}
```

- [ ] **Step 4: Remove now-unused constants `LOGIC_YES_ACTIVE` and `LOGIC_NO_ACTIVE`**

At the top of the file (lines 3-4), remove:

```javascript
const LOGIC_YES_ACTIVE = ["bg-green-50", "dark:bg-green-900/20", "font-semibold", "text-green-800", "dark:text-green-300"]
const LOGIC_NO_ACTIVE = ["bg-red-50", "dark:bg-red-900/20", "font-semibold", "text-red-800", "dark:text-red-300"]
```

Update `ALL_LOGIC_CLASSES` (line 6) since it references the removed constants:

```javascript
const LOGIC_DIMMED = ["text-slate-400", "dark:text-slate-500"]
const ALL_HIGHLIGHT_CLASSES = ["bg-green-50", "dark:bg-green-900/20", "font-semibold", "text-green-800", "dark:text-green-300", "bg-red-50", "dark:bg-red-900/20", "text-red-800", "dark:text-red-300"]
const ALL_LOGIC_CLASSES = [...ALL_HIGHLIGHT_CLASSES, ...LOGIC_DIMMED]
```

- [ ] **Step 5: Run full test suite**

Run: `bin/rails test`

Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/components/inspection_item_component.html.erb app/javascript/controllers/inspection_item_controller.js
git commit -m "feat(stimulus): support yes_means_safe polarity in dynamic logic highlighting"
```

---

### Task 8: Update Existing Tests — Fix Hardcoded Polarity Assumptions

**Files:**
- Modify: `test/components/inspection_item_component_test.rb`

- [ ] **Step 1: Update existing test for `has_risk: true` highlight**

The existing test "highlights selected answer — no when has_risk is true" uses `risky_villa_rights_011` which is now an inverted-polarity question. Update:

Find:
```ruby
test "highlights selected answer — no when has_risk is true" do
  result = inspection_results(:risky_villa_rights_011)
  assert_equal true, result.has_risk
  render_inline(InspectionItemComponent.new(result: result))

  assert_selector "[data-logic-selected='no']"
  refute_selector "[data-logic-selected='yes']"
end
```

Replace with:
```ruby
test "highlights selected answer — no when has_risk is true (normal polarity)" do
  result = inspection_results(:risky_villa_rights_011)
  # rights_011 is now yes_means_safe: false, so has_risk: true → yes selected
  # Use a normal polarity fixture instead
  result = inspection_results(:manual_risk)
  result.inspection_item.update!(yes_means_safe: true, logic: '{"yes": "safe", "no": "risky"}')
  result.update!(has_risk: true, source_type: "auto")
  render_inline(InspectionItemComponent.new(result: result))

  assert_selector "[data-logic-selected='no']"
  refute_selector "[data-logic-selected='yes']"
end
```

- [ ] **Step 2: Run full test suite**

Run: `bin/rails test`

Expected: All PASS.

- [ ] **Step 3: Commit**

```bash
git add test/components/inspection_item_component_test.rb
git commit -m "test(component): update existing tests for yes_means_safe polarity change"
```

---

### Task 9: Final Verification — Run Full CI Pipeline

**Files:** None (verification only)

- [ ] **Step 1: Run rubocop**

Run: `bin/rubocop`

Expected: No offenses. Fix any style issues if found.

- [ ] **Step 2: Run brakeman**

Run: `bin/brakeman --quiet --no-pager`

Expected: No warnings.

- [ ] **Step 3: Run full test suite**

Run: `bin/rails test`

Expected: All tests PASS.

- [ ] **Step 4: Run seeds to verify end-to-end**

Run: `bin/rails db:reset`

Then:
```bash
bin/rails runner "
  false_count = InspectionItem.where(yes_means_safe: false).count
  true_count = InspectionItem.where(yes_means_safe: true).count
  puts \"yes_means_safe: false → #{false_count} items\"
  puts \"yes_means_safe: true  → #{true_count} items\"
"
```

Expected:
```
yes_means_safe: false → 15 items
yes_means_safe: true  → [remaining items count]
```

- [ ] **Step 5: Commit any remaining fixes**

If any fixes were needed from verification, commit them with appropriate messages.
