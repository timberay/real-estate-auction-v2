# Checklist Question Hierarchy Redesign

## Summary

Introduce a multi-level `depends_on` hierarchy for checklist questions. Add a new
intermediate question (`rights-024`: "대항력 있는 임차인이 있습니까?") under `rights-003`,
move 7 existing questions under it, incorporate 3 eviction questions as children of
`rights-003`, remove the redundant `rights-015`, and clean up question text by removing
conditions already covered by parent questions.

## Background

The current `depends_on` structure supports only 1-level parent-child relationships.
All children of `rights-003` ("임차인이 거주하고 있습니까?") are direct children, but many
of them are only meaningful when the tenant has 대항력 (opposing rights). This creates:

- Redundant phrasing: "대항력 있는 임차인이 없거나, 있더라도..." in every child question
- Missing intermediate logic: no way to filter 대항력-specific questions
- Orphaned eviction questions: `eviction-003/004/006` are contextually children of
  `rights-003` but have no `depends_on` relationship

## Approach

Extend the existing `depends_on` JSON structure (no schema changes) with recursive
`skip_for?` evaluation. Maximum depth: 2 levels (grandparent → parent → child).

## Seed Data Changes

### New question: `rights-024`

```json
{
  "id": "rights-024",
  "tab": "권리분석",
  "tab_position": 4,
  "category": "권리분석",
  "question": "대항력 있는 임차인이 있습니까?",
  "priority": "상",
  "yes_means_safe": false,
  "depends_on": { "code": "rights-003", "show_when_risk": true }
}
```

### depends_on reassignment (7 items)

Move from `rights-003` to `rights-024`:

| Code | New depends_on |
|------|---------------|
| rights-009 | `{ "code": "rights-024", "show_when_risk": true }` |
| rights-006 | `{ "code": "rights-024", "show_when_risk": true }` |
| rights-014 | `{ "code": "rights-024", "show_when_risk": true }` |
| rights-013 | `{ "code": "rights-024", "show_when_risk": true }` |
| rights-010 | `{ "code": "rights-024", "show_when_risk": true }` |
| rights-016 | `{ "code": "rights-024", "show_when_risk": true }` |
| rights-012 | `{ "code": "rights-024", "show_when_risk": true }` |

### Eviction questions incorporated (3 items)

| Code | New depends_on | Category change |
|------|---------------|----------------|
| eviction-003 | `{ "code": "rights-003", "show_when_risk": true }` | "명도 난이도" → "권리분석" |
| eviction-004 | `{ "code": "rights-003", "show_when_risk": true }` | "명도 난이도" → "권리분석" |
| eviction-006 | `{ "code": "rights-003", "show_when_risk": true }` | "명도 난이도" → "권리분석" |

### Question text cleanup (9 items)

Remove parent-covered condition phrases:

| Code | Before | After |
|------|--------|-------|
| rights-009 | 대항력 있는 임차인이 없거나, 있더라도 HUG 등 채권자의 대항력 포기 확약서가 제출되어 있습니까? | HUG 등 채권자의 대항력 포기 확약서가 제출되어 있습니까? |
| rights-006 | 대항력 있는 임차인이 없거나, 있더라도 배당요구 종기일 이전에 배당요구를 신청했습니까? | 배당요구 종기일 이전에 배당요구를 신청했습니까? |
| rights-014 | 대항력 있는 임차인이 없거나, 있더라도 보증금·확정일자·배당요구 정보가 모두 확인되었습니까? | 보증금·확정일자·배당요구 정보가 모두 확인되었습니까? |
| rights-013 | 대항력 있는 임차인이 없거나, 임차권 등기가 설정되어 있지 않습니까? | 임차권 등기가 설정되어 있지 않습니까? |
| rights-010 | 대항력 있는 임차인의 미배당 보증금이 있습니까? | 미배당 보증금이 있습니까? |
| rights-016 | 전입신고일이 말소기준일 이전인 대항력 있는 임차인이 있습니까? | 전입신고일이 말소기준일 이전입니까? |
| eviction-003 | 점유자가 없거나(공실), 명도가 수월한 점유자입니까? | 명도가 수월한 점유자입니까? |
| eviction-004 | 임차인이 없거나, 소액임차인 요건을 충족하여 최우선변제금을 배당받습니까? | 소액임차인 요건을 충족하여 최우선변제금을 배당받습니까? |
| eviction-006 | 점유자가 없거나, 배당금 수령을 위해 명도확인서가 필수적인 상황입니까? | 배당금 수령을 위해 명도확인서가 필수적인 상황입니까? |

### Deletion

`rights-015` (임차권/전세권이 없거나, 모두 말소기준권리 이후(후순위)여서 소멸 대상입니까?)
— redundant with `rights-024` "아니오" answer (no 대항력 = already extinguished).

### Data cleanup for `rights-015` deletion

`InspectionItem` has `has_many :inspection_results, dependent: :destroy`. When
`rights-015` is removed from the seed and `db/seeds.rb` runs the stale-item cleanup
(`InspectionItem.where.not(code: seeded_codes).destroy_all`), all associated
`InspectionResult` records are automatically cascade-deleted.

The rating service (`InspectionRatingService`) and grade controller both use
`visible_for?` which filters by live `InspectionItem` records — orphaned results
cannot appear. No additional migration or data patch is required.

## Final Tree Structure

```
rights-003: 전입신고된 제3자 임차인이 거주하고 있습니까?
├── rights-024: 대항력 있는 임차인이 있습니까? (NEW)
│   ├── rights-009: HUG 등 채권자의 대항력 포기 확약서가 제출되어 있습니까?
│   ├── rights-006: 배당요구 종기일 이전에 배당요구를 신청했습니까?
│   ├── rights-014: 보증금·확정일자·배당요구 정보가 모두 확인되었습니까?
│   ├── rights-013: 임차권 등기가 설정되어 있지 않습니까?
│   ├── rights-010: 미배당 보증금이 있습니까?
│   ├── rights-016: 전입신고일이 말소기준일 이전입니까?
│   └── rights-012: 선순위 임차권 등기 또는 새로 전입한 미상 임차인이 있습니까?
├── eviction-003: 명도가 수월한 점유자입니까?
├── eviction-004: 소액임차인 요건을 충족하여 최우선변제금을 배당받습니까?
└── eviction-006: 배당금 수령을 위해 명도확인서가 필수적인 상황입니까?

eviction-005: 인수해야 할 미납 관리비가 없거나, 감당 가능한 수준입니까? (독립 유지)
```

## Model Changes

### `InspectionItem#skip_for?` — recursive evaluation

```ruby
def skip_for?(answered_results_by_code, all_items_by_code: {}, visited: Set.new)
  return false if depends_on.blank?
  return true if visited.include?(code) # circular dependency guard

  parent_code = depends_on["code"]
  parent_item = all_items_by_code[parent_code]

  # If parent itself is skipped, child is also skipped
  if parent_item&.skip_for?(answered_results_by_code, all_items_by_code: all_items_by_code, visited: visited | [code])
    return true
  end

  parent_result = answered_results_by_code[parent_code]
  return true if parent_result.nil? || parent_result.has_risk.nil?
  parent_result.has_risk != depends_on["show_when_risk"]
end
```

### `InspectionItem#visible_for?` — signature change

```ruby
def visible_for?(property_type:, answered_results: {}, all_items_by_code: {})
  applicable_for?(property_type) &&
    !skip_for?(answered_results, all_items_by_code: all_items_by_code, visited: Set.new)
end
```

## Caller Changes

All callers need to build and pass `all_items_by_code`. Each already loads
`inspection_item` via `includes(:inspection_item)`, so no additional queries needed.

```ruby
# Build once from existing data:
all_items_by_code = all_results.map(&:inspection_item).index_by(&:code)
```

### Affected files

| File | Change |
|------|--------|
| `app/controllers/inspections/tabs_controller.rb` | Build `all_items_by_code`, pass to `skip_for?` and `visible_for?` |
| `app/controllers/inspections/grades_controller.rb` | Build `all_items_by_code`, pass to `visible_for?` |
| `app/components/inspection_tabs_component.rb` | Build `all_items_by_code`, pass to `visible_for?` |
| `app/services/inspection_rating_service.rb` | Build `all_items_by_code`, pass to `visible_for?` |

## Stimulus Controller Changes

### `checklist_dependency_controller.js` — cascade hide + re-evaluate on show

```javascript
toggle(event) {
  const card = event.target.closest("[data-item-code]")
  if (!card) return

  const parentCode = card.dataset.itemCode
  const parentHasRisk = event.target.value === "true"

  this.element.querySelectorAll(`[data-depends-on-code="${parentCode}"]`).forEach(el => {
    const showWhenRisk = el.dataset.dependsOnShowWhenRisk === "true"
    if (parentHasRisk === showWhenRisk) {
      el.classList.remove("hidden")
      // Re-evaluate: if this child already has an answer, cascade show its grandchildren
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

  // Find the currently checked radio value for this child
  const checked = el.querySelector('input[type="radio"]:checked')
  if (!checked) return // unanswered — grandchildren stay hidden (server default)

  const childHasRisk = checked.value === "true"
  this.element.querySelectorAll(`[data-depends-on-code="${childCode}"]`).forEach(grandchild => {
    const showWhenRisk = grandchild.dataset.dependsOnShowWhenRisk === "true"
    if (childHasRisk === showWhenRisk) {
      grandchild.classList.remove("hidden")
      this.reEvaluateDescendants(grandchild) // recursive for deeper levels
    } else {
      grandchild.classList.add("hidden")
      this.hideDescendants(grandchild.dataset.itemCode)
    }
  })
}
```

Key behavior:
- Parent hidden → all descendants cascade hidden
- Parent shown → direct children shown, **and if a child already has an answer, its grandchildren are re-evaluated recursively**
- Unanswered intermediate parent → grandchildren stay hidden (correct default)

## No Changes Required

- DB schema / migrations
- `depends_on` JSON structure (`{ "code": "...", "show_when_risk": true }`)
- ERB templates / data attributes
- `PdfAnalysisService`, `InspectionResultMapper`, `PdfPromptBuilder`
- `applicable_types` filtering logic

## Test Strategy

### Modified test files

| File | Reason |
|------|--------|
| `test/models/inspection_item_test.rb` | `skip_for?` / `visible_for?` signature change + recursive tests |
| `test/controllers/inspections/tabs_controller_test.rb` | `all_items_by_code` passing |
| `test/controllers/inspections/grades_controller_test.rb` | `visible_for?` call change |
| `test/services/inspection_rating_service_test.rb` | `visible_for?` call change |

### New test cases (model)

| Case | Expected |
|------|----------|
| Parent unanswered → child skip | `skip_for?` = true |
| Parent risk → child shown → grandchild (intermediate unanswered) | grandchild `skip_for?` = true |
| Parent risk → intermediate risk → grandchild shown | grandchild `skip_for?` = false |
| Parent safe → intermediate + grandchild all skip | recursive cascade |
| Intermediate safe → grandchild skip (parent is risk) | intermediate condition check |

### Stimulus verification

| Case | Expected |
|------|----------|
| rights-003 "위험" | rights-024 + eviction-003/004/006 shown |
| rights-024 "위험" | 7 grandchildren shown |
| rights-003 → "안전" | rights-024 + 7 grandchildren + eviction 3 all hidden |
| rights-024 → "안전" | 7 grandchildren hidden, eviction 3 remain |
| rights-003 "안전" → "위험" (rights-024 already "위험") | rights-024 shown + 7 grandchildren re-evaluated and shown |
| Circular dependency in seed data | `skip_for?` returns true (guard), no SystemStackError |
