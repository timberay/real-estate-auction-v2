# Checklist Hierarchy Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce multi-level `depends_on` hierarchy with recursive `skip_for?`, add `rights-024` intermediate question, clean up redundant question text, and delete obsolete items.

**Architecture:** Extend existing `depends_on` JSON structure (no schema changes) with recursive `skip_for?` in the model, cascade hide/re-evaluate in Stimulus, and seed data restructuring. All callers pass `all_items_by_code` for parent-item lookup.

**Tech Stack:** Rails 8.1, Minitest, Stimulus JS, SQLite JSON

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `db/seeds/checklist_items_summary.json` | Modify | Seed data: add rights-024, reassign depends_on, clean text, delete items |
| `app/models/inspection_item.rb` | Modify | Recursive `skip_for?` with visited guard, `visible_for?` signature |
| `test/models/inspection_item_test.rb` | Modify | Update existing tests + add recursive/circular tests |
| `app/controllers/inspections/tabs_controller.rb` | Modify | Build and pass `all_items_by_code` |
| `app/controllers/inspections/grades_controller.rb` | Modify | Build and pass `all_items_by_code` |
| `app/components/inspection_tabs_component.rb` | Modify | Build and pass `all_items_by_code` |
| `app/services/inspection_rating_service.rb` | Modify | Build and pass `all_items_by_code` |
| `app/javascript/controllers/checklist_dependency_controller.js` | Modify | Cascade hide + reEvaluateDescendants |
| `test/controllers/inspections/tabs_controller_test.rb` | Modify | Update depends_on assertions for rights-024 |
| `test/controllers/inspections/grades_controller_test.rb` | Verify | Ensure integration test still passes |
| `test/services/inspection_rating_service_test.rb` | Verify | Ensure service tests still pass |

---

### Task 1: Update seed data — add rights-024 and restructure hierarchy

**Files:**
- Modify: `db/seeds/checklist_items_summary.json`

This task modifies the JSON seed file. Use a Python script to make the changes programmatically to avoid manual JSON editing errors.

- [ ] **Step 1: Write a Python script to modify the seed data**

Create a temporary script `tmp/update_seeds.py`:

```python
import json
import sys

with open("db/seeds/checklist_items_summary.json") as f:
    items = json.load(f)

items_by_id = {item["id"]: item for item in items}

# 1. Add rights-024 after rights-003 (tab_position 4)
rights_024 = {
    "id": "rights-024",
    "tab": "권리분석",
    "tab_position": 4,
    "category": "권리분석",
    "question": "대항력 있는 임차인이 있습니까?",
    "description": "임차인에게 대항력이 있으면 보증금 전액을 낙찰자가 인수해야 할 수 있습니다. 대항력 유무는 전입신고일과 말소기준권리 설정일의 선후관계로 판단합니다.",
    "logic": {
        "yes": "대항력 있는 임차인의 보증금 인수 리스크를 세부 점검해야 합니다.",
        "no": "임차인에게 대항력이 없어 보증금 인수 리스크가 없습니다."
    },
    "priority": "상",
    "yes_means_safe": False,
    "depends_on": {"code": "rights-003", "show_when_risk": True}
}

# Insert after rights-003
idx = next(i for i, item in enumerate(items) if item["id"] == "rights-003")
items.insert(idx + 1, rights_024)

# 2. Reassign 7 items from rights-003 to rights-024
reassign_to_024 = ["rights-009", "rights-006", "rights-010", "rights-014",
                    "rights-016", "rights-012", "rights-013"]
for item in items:
    if item["id"] in reassign_to_024:
        item["depends_on"] = {"code": "rights-024", "show_when_risk": True}

# 3. Incorporate 3 eviction items under rights-003
eviction_incorporate = ["eviction-003", "eviction-004", "eviction-006"]
for item in items:
    if item["id"] in eviction_incorporate:
        item["depends_on"] = {"code": "rights-003", "show_when_risk": True}
        item["category"] = "권리분석"

# 4. Question text cleanup — hierarchy-related (9 items)
text_changes = {
    "rights-009": "HUG 등 채권자의 대항력 포기 확약서가 제출되어 있습니까?",
    "rights-006": "배당요구 종기일 이전에 배당요구를 신청했습니까?",
    "rights-014": "보증금·확정일자·배당요구 정보가 모두 확인되었습니까?",
    "rights-013": "임차권 등기가 설정되어 있지 않습니까?",
    "rights-010": "미배당 보증금이 있습니까?",
    "rights-016": "전입신고일이 말소기준일 이전입니까?",
    "eviction-003": "명도가 수월한 점유자입니까?",
    "eviction-004": "소액임차인 요건을 충족하여 최우선변제금을 배당받습니까?",
    "eviction-006": "배당금 수령을 위해 명도확인서가 필수적인 상황입니까?",
}
for item in items:
    if item["id"] in text_changes:
        item["question"] = text_changes[item["id"]]

# 5. Additional question cleanup (4 items — condition/type simplification)
for item in items:
    if item["id"] == "property-003":
        item["question"] = "해당 물건 내부에서 외부가 잘 보입니까?"
        item["applicable_types"] = None
    elif item["id"] == "resale-004":
        item["question"] = "감정가가 주변 시세 수준입니까?"
        item["applicable_types"] = None
    elif item["id"] == "inspect-004":
        item["question"] = "주거용/업무용을 확인했습니까?"
        item["applicable_types"] = ["오피스텔"]
    elif item["id"] == "rights-019":
        item["question"] = "토지와 건물이 일체로 매각되는 물건입니까?"
        item["applicable_types"] = None

# 6. Delete rights-015 and inspect-007
items = [item for item in items if item["id"] not in ("rights-015", "inspect-007")]

with open("db/seeds/checklist_items_summary.json", "w") as f:
    json.dump(items, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"Done. {len(items)} items written.")
```

- [ ] **Step 2: Run the script**

Run: `python3 tmp/update_seeds.py`
Expected: `Done. XX items written.`

- [ ] **Step 3: Verify the changes**

Run:
```bash
python3 -c "
import json
with open('db/seeds/checklist_items_summary.json') as f:
    items = json.load(f)

# Verify rights-024 exists
r024 = next(i for i in items if i['id'] == 'rights-024')
assert r024['depends_on'] == {'code': 'rights-003', 'show_when_risk': True}
print('rights-024 OK')

# Verify 7 items point to rights-024
for code in ['rights-009','rights-006','rights-010','rights-014','rights-016','rights-012','rights-013']:
    item = next(i for i in items if i['id'] == code)
    assert item['depends_on']['code'] == 'rights-024', f'{code} wrong depends_on'
print('7 reassigned OK')

# Verify 3 eviction items
for code in ['eviction-003','eviction-004','eviction-006']:
    item = next(i for i in items if i['id'] == code)
    assert item['depends_on'] == {'code': 'rights-003', 'show_when_risk': True}
    assert item['category'] == '권리분석'
print('3 eviction OK')

# Verify deletions
assert not any(i['id'] == 'rights-015' for i in items)
assert not any(i['id'] == 'inspect-007' for i in items)
print('deletions OK')

# Verify question text changes
assert next(i for i in items if i['id'] == 'rights-009')['question'] == 'HUG 등 채권자의 대항력 포기 확약서가 제출되어 있습니까?'
assert next(i for i in items if i['id'] == 'property-003')['question'] == '해당 물건 내부에서 외부가 잘 보입니까?'
assert next(i for i in items if i['id'] == 'inspect-004')['applicable_types'] == ['오피스텔']
print('text changes OK')

print('All verifications passed!')
"
```

Expected: `All verifications passed!`

- [ ] **Step 4: Clean up temp script and commit**

```bash
rm tmp/update_seeds.py
git add db/seeds/checklist_items_summary.json
git commit -m "refactor(seeds): restructure checklist hierarchy with rights-024

- Add rights-024 (대항력) as intermediate question under rights-003
- Reassign 7 items from rights-003 to rights-024
- Incorporate eviction-003/004/006 under rights-003
- Clean up 13 question texts (remove redundant conditions)
- Update applicable_types for property-003, resale-004, inspect-004, rights-019
- Delete rights-015 and inspect-007"
```

---

### Task 2: Update model — recursive skip_for? with circular dependency guard

**Files:**
- Modify: `app/models/inspection_item.rb:31-49`
- Test: `test/models/inspection_item_test.rb`

- [ ] **Step 1: Write failing tests for recursive skip_for?**

Add these tests at the end of `test/models/inspection_item_test.rb` (before the final `end`):

```ruby
  # Multi-level skip_for? tests
  test "skip_for? cascades when parent is skipped (grandparent unanswered)" do
    grandparent = InspectionItem.new(code: "gp-001", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상", depends_on: nil)
    parent = InspectionItem.new(code: "p-001", tab: "rights_analysis", tab_position: 2,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "gp-001", "show_when_risk" => true })
    child = InspectionItem.new(code: "c-001", tab: "rights_analysis", tab_position: 3,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "p-001", "show_when_risk" => true })

    all_items = { "gp-001" => grandparent, "p-001" => parent, "c-001" => child }
    # grandparent unanswered → parent skipped → child skipped
    assert child.skip_for?({}, all_items_by_code: all_items)
  end

  test "skip_for? shows grandchild when full chain matches" do
    grandparent = InspectionItem.new(code: "gp-002", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상", depends_on: nil)
    parent = InspectionItem.new(code: "p-002", tab: "rights_analysis", tab_position: 2,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "gp-002", "show_when_risk" => true })
    child = InspectionItem.new(code: "c-002", tab: "rights_analysis", tab_position: 3,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "p-002", "show_when_risk" => true })

    gp_result = OpenStruct.new(has_risk: true)
    p_result = OpenStruct.new(has_risk: true)
    answered = { "gp-002" => gp_result, "p-002" => p_result }
    all_items = { "gp-002" => grandparent, "p-002" => parent, "c-002" => child }

    refute child.skip_for?(answered, all_items_by_code: all_items)
  end

  test "skip_for? skips grandchild when intermediate parent is safe" do
    grandparent = InspectionItem.new(code: "gp-003", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상", depends_on: nil)
    parent = InspectionItem.new(code: "p-003", tab: "rights_analysis", tab_position: 2,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "gp-003", "show_when_risk" => true })
    child = InspectionItem.new(code: "c-003", tab: "rights_analysis", tab_position: 3,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "p-003", "show_when_risk" => true })

    gp_result = OpenStruct.new(has_risk: true)
    p_result = OpenStruct.new(has_risk: false) # safe → child should be skipped
    answered = { "gp-003" => gp_result, "p-003" => p_result }
    all_items = { "gp-003" => grandparent, "p-003" => parent, "c-003" => child }

    assert child.skip_for?(answered, all_items_by_code: all_items)
  end

  test "skip_for? handles circular dependency without infinite loop" do
    item_a = InspectionItem.new(code: "circ-a", tab: "rights_analysis", tab_position: 1,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "circ-b", "show_when_risk" => true })
    item_b = InspectionItem.new(code: "circ-b", tab: "rights_analysis", tab_position: 2,
      category: "권리분석", question: "Q?", priority: "상",
      depends_on: { "code" => "circ-a", "show_when_risk" => true })

    all_items = { "circ-a" => item_a, "circ-b" => item_b }
    # Should not raise SystemStackError, should return true (skip)
    assert item_a.skip_for?({}, all_items_by_code: all_items)
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH" && bin/rails test test/models/inspection_item_test.rb -v 2>&1 | grep -E "(FAIL|ERROR|skip_for\? cascades|skip_for\? shows grandchild|skip_for\? skips grandchild|skip_for\? handles circular)"`

Expected: 4 failures/errors (methods don't accept `all_items_by_code` yet)

- [ ] **Step 3: Update skip_for? with recursive logic and circular guard**

Replace the `skip_for?` and `visible_for?` methods in `app/models/inspection_item.rb:31-49`:

```ruby
  def visible_for?(property_type:, answered_results: {}, all_items_by_code: {})
    applicable_for?(property_type) &&
      !skip_for?(answered_results, all_items_by_code: all_items_by_code)
  end

  def depends_on
    val = super
    val.is_a?(String) ? JSON.parse(val) : val
  end

  def skip_for?(answered_results_by_code, all_items_by_code: {}, visited: Set.new)
    return false if depends_on.blank?
    return true if visited.include?(code)

    parent_code = depends_on["code"]
    parent_item = all_items_by_code[parent_code]

    if parent_item&.skip_for?(answered_results_by_code, all_items_by_code: all_items_by_code, visited: visited | [code])
      return true
    end

    parent_result = answered_results_by_code[parent_code]
    return true if parent_result.nil? || parent_result.has_risk.nil?
    parent_result.has_risk != depends_on["show_when_risk"]
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH" && bin/rails test test/models/inspection_item_test.rb -v`

Expected: 26 runs, 0 failures, 0 errors

- [ ] **Step 5: Commit**

```bash
git add app/models/inspection_item.rb test/models/inspection_item_test.rb
git commit -m "feat(model): add recursive skip_for? with circular dependency guard"
```

---

### Task 3: Update callers — tabs_controller

**Files:**
- Modify: `app/controllers/inspections/tabs_controller.rb:14-27,66-72`

- [ ] **Step 1: Update tabs_controller to build and pass all_items_by_code**

In `app/controllers/inspections/tabs_controller.rb`, modify the `edit` action. After line 14 (`answered_context = ...`), add:

```ruby
      all_items_by_code = all_results.map(&:inspection_item).index_by(&:code)
```

Then update line 24 (the `skip_for?` call) to pass `all_items_by_code`:

```ruby
      @dependency_hidden_ids = tab_results
        .select { |r| r.inspection_item.skip_for?(answered_context, all_items_by_code: all_items_by_code) }
        .map(&:id).to_set
```

In the `update` action, after line 66 (`answered_context = ...`), add:

```ruby
      all_items_by_code = all_results_for_count.map(&:inspection_item).index_by(&:code)
```

Then update line 71 (the `visible_for?` call):

```ruby
        .select { |r| r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context, all_items_by_code: all_items_by_code) }
```

- [ ] **Step 2: Run existing controller tests**

Run: `export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH" && bin/rails test test/controllers/inspections/tabs_controller_test.rb -v`

Expected: All pass (6 runs, 0 failures)

- [ ] **Step 3: Commit**

```bash
git add app/controllers/inspections/tabs_controller.rb
git commit -m "refactor(controller): pass all_items_by_code in tabs_controller"
```

---

### Task 4: Update callers — grades_controller

**Files:**
- Modify: `app/controllers/inspections/grades_controller.rb:16-20`

- [ ] **Step 1: Update grades_controller**

In `app/controllers/inspections/grades_controller.rb`, after line 16 (`answered_context = ...`), add:

```ruby
      all_items_by_code = all_results.map(&:inspection_item).index_by(&:code)
```

Then update line 20 (the `visible_for?` call):

```ruby
      @results_by_tab = all_results
        .select { |r| r.inspection_item.visible_for?(property_type:, answered_results: answered_context, all_items_by_code: all_items_by_code) }
        .group_by { |r| r.inspection_item.tab }
```

- [ ] **Step 2: Run existing controller tests**

Run: `export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH" && bin/rails test test/controllers/inspections/grades_controller_test.rb -v`

Expected: All pass (4 runs, 0 failures)

- [ ] **Step 3: Commit**

```bash
git add app/controllers/inspections/grades_controller.rb
git commit -m "refactor(controller): pass all_items_by_code in grades_controller"
```

---

### Task 5: Update callers — inspection_tabs_component

**Files:**
- Modify: `app/components/inspection_tabs_component.rb:38-42`

- [ ] **Step 1: Update inspection_tabs_component**

In `app/components/inspection_tabs_component.rb`, in `load_tab_stats` method, after line 38 (`answered_context = ...`), add:

```ruby
    all_items_by_code = all_results.map(&:inspection_item).index_by(&:code)
```

Then update line 42 (the `visible_for?` call):

```ruby
      r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context, all_items_by_code: all_items_by_code)
```

- [ ] **Step 2: Run full test suite to verify no regressions**

Run: `export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH" && bin/rails test test/components/ -v 2>&1 | tail -5`

Expected: 0 failures, 0 errors

- [ ] **Step 3: Commit**

```bash
git add app/components/inspection_tabs_component.rb
git commit -m "refactor(component): pass all_items_by_code in inspection_tabs_component"
```

---

### Task 6: Update callers — inspection_rating_service

**Files:**
- Modify: `app/services/inspection_rating_service.rb:67-71`

- [ ] **Step 1: Update inspection_rating_service**

In `app/services/inspection_rating_service.rb`, in the `visible_results` method, after line 67 (`answered_context = ...`), add:

```ruby
      all_items_by_code = all_results.map(&:inspection_item).index_by(&:code)
```

Then update line 71 (the `visible_for?` call):

```ruby
        r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context, all_items_by_code: all_items_by_code)
```

- [ ] **Step 2: Run service tests**

Run: `export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH" && bin/rails test test/services/inspection_rating_service_test.rb -v`

Expected: All pass (0 failures)

- [ ] **Step 3: Commit**

```bash
git add app/services/inspection_rating_service.rb
git commit -m "refactor(service): pass all_items_by_code in inspection_rating_service"
```

---

### Task 7: Update Stimulus controller — cascade hide + reEvaluateDescendants

**Files:**
- Modify: `app/javascript/controllers/checklist_dependency_controller.js`

- [ ] **Step 1: Replace the Stimulus controller**

Replace the entire content of `app/javascript/controllers/checklist_dependency_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  toggle(event) {
    const card = event.target.closest("[data-item-code]")
    if (!card) return

    const parentCode = card.dataset.itemCode
    const parentHasRisk = event.target.value === "true"

    this.element.querySelectorAll(`[data-depends-on-code="${parentCode}"]`).forEach(el => {
      const showWhenRisk = el.dataset.dependsOnShowWhenRisk === "true"
      if (parentHasRisk === showWhenRisk) {
        el.classList.remove("hidden")
        this.reEvaluateDescendants(el)
      } else {
        el.classList.add("hidden")
        this.hideDescendants(el.dataset.itemCode)
      }
    })
  }

  hideDescendants(parentCode) {
    this.element.querySelectorAll(`[data-depends-on-code="${parentCode}"]`).forEach(el => {
      el.classList.add("hidden")
      this.hideDescendants(el.dataset.itemCode)
    })
  }

  reEvaluateDescendants(el) {
    const childCode = el.dataset.itemCode
    if (!childCode) return

    const checked = el.querySelector('input[type="radio"]:checked')
    if (!checked) return

    const childHasRisk = checked.value === "true"
    this.element.querySelectorAll(`[data-depends-on-code="${childCode}"]`).forEach(grandchild => {
      const showWhenRisk = grandchild.dataset.dependsOnShowWhenRisk === "true"
      if (childHasRisk === showWhenRisk) {
        grandchild.classList.remove("hidden")
        this.reEvaluateDescendants(grandchild)
      } else {
        grandchild.classList.add("hidden")
        this.hideDescendants(grandchild.dataset.itemCode)
      }
    })
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/controllers/checklist_dependency_controller.js
git commit -m "feat(stimulus): add cascade hide and reEvaluateDescendants for multi-level depends_on"
```

---

### Task 8: Update test fixtures and integration tests

**Files:**
- Modify: `test/fixtures/inspection_items.yml`
- Modify: `test/controllers/inspections/tabs_controller_test.rb:92-109`

The tabs_controller_test checks `[data-depends-on-code='rights-003']` for dependent items. After the hierarchy change, `rights-009` now depends on `rights-024` (not `rights-003` directly). We need to add a `rights-024` fixture and update the test assertions.

- [ ] **Step 1: Add rights-024 fixture**

Add to `test/fixtures/inspection_items.yml`:

```yaml
rights_024:
  code: "rights-024"
  tab: 0
  tab_position: 4
  category: "권리분석"
  question: "대항력 있는 임차인이 있습니까?"
  description: "대항력 확인"
  logic: '{"yes": "위험", "no": "안전"}'
  data_source_name: "수동 입력"
  priority: "상"
  yes_means_safe: false
  depends_on: '{"code": "rights-003", "show_when_risk": true}'
```

Update the `rights_009` fixture to depend on `rights-024` instead of `rights-003`. Find and update:

```yaml
rights_009:
  code: "rights-009"
  tab: 0
  tab_position: 5
  category: "권리분석"
  question: "HUG 등 채권자의 대항력 포기 확약서가 제출되어 있습니까?"
  description: "HUG 확약서 확인"
  logic: '{"yes": "안전", "no": "위험"}'
  data_source_name: "수동 입력"
  priority: "상"
  yes_means_safe: true
  depends_on: '{"code": "rights-024", "show_when_risk": true}'
```

- [ ] **Step 2: Add rights-024 inspection_result fixture**

Check `test/fixtures/inspection_results.yml` for the pattern used by `safe_apartment` results, and add a result for `rights-024`. The result should have `has_risk: false` for `safe_apartment` (matching the safe scenario where there are no tenants with 대항력).

```yaml
safe_apartment_rights_024:
  property: safe_apartment
  inspection_item: rights_024
  user: guest
  source_type: "auto"
  has_risk: false
  evidence: '{"source_label": "AI", "confidence": "high", "reasoning": "대항력 임차인 없음"}'
```

For `risky_villa`, add a result with `has_risk: true`:

```yaml
risky_villa_rights_024:
  property: risky_villa
  inspection_item: rights_024
  user: guest
  source_type: "auto"
  has_risk: true
  evidence: '{"source_label": "AI", "confidence": "high", "reasoning": "대항력 임차인 있음"}'
```

- [ ] **Step 3: Update tabs_controller_test assertions**

In `test/controllers/inspections/tabs_controller_test.rb`, update the two dependency tests.

Replace the test at lines 92-99 (hidden when parent safe):

```ruby
  test "edit renders dependent items hidden when parent has_risk is false" do
    # rights-003 has_risk=false → rights-024 should be hidden
    # rights-024 depends_on rights-003 show_when_risk=true
    get edit_property_inspections_tab_url(@property, tab_key: "rights_analysis")
    assert_response :success
    assert_select "[data-depends-on-code='rights-003']" do |elements|
      elements.each { |el| assert_match(/hidden/, el["class"].to_s) }
    end
  end
```

Replace the test at lines 101-110 (visible when parent risky):

```ruby
  test "edit renders dependent items visible when parent has_risk matches show_when_risk" do
    risky = properties(:risky_villa)
    UserProperty.find_or_create_by!(user: users(:guest), property: risky)
    # risky_villa: rights-003 has_risk=true → rights-024 visible
    get edit_property_inspections_tab_url(risky, tab_key: "rights_analysis")
    assert_response :success
    assert_select "[data-depends-on-code='rights-003']" do |elements|
      elements.each { |el| refute_match(/hidden/, el["class"].to_s) }
    end
  end
```

- [ ] **Step 4: Run all tests**

Run: `export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH" && bin/rails test -v 2>&1 | tail -10`

Expected: All pass, 0 failures, 0 errors

- [ ] **Step 5: Commit**

```bash
git add test/fixtures/inspection_items.yml test/fixtures/inspection_results.yml test/controllers/inspections/tabs_controller_test.rb
git commit -m "test: update fixtures and assertions for rights-024 hierarchy"
```

---

### Task 9: Run full test suite and verify

- [ ] **Step 1: Run the full test suite**

Run: `export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH" && bin/rails test 2>&1 | tail -5`

Expected: 0 failures, 0 errors

- [ ] **Step 2: Run seed to verify data loads correctly**

Run: `export PATH="$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH" && bin/rails db:seed 2>&1 | grep -E "(inspection items|Seed complete)"`

Expected:
```
  -> XX inspection items (removed 2 stale)
Seed complete!
```

- [ ] **Step 3: Verify the hierarchy in seeded data**

Run:
```bash
python3 -c "
import json
with open('db/seeds/checklist_items_summary.json') as f:
    items = json.load(f)

parents = {}
for item in items:
    dep = item.get('depends_on')
    if dep and isinstance(dep, dict):
        pc = dep['code']
        if pc not in parents:
            parents[pc] = []
        parents[pc].append(item['id'])

for pc in ['rights-003', 'rights-024']:
    if pc in parents:
        print(f'{pc}: {parents[pc]}')
"
```

Expected:
```
rights-003: ['rights-024', 'eviction-003', 'eviction-004', 'eviction-006']
rights-024: ['rights-009', 'rights-006', 'rights-010', 'rights-014', 'rights-016', 'rights-012', 'rights-013']
```
