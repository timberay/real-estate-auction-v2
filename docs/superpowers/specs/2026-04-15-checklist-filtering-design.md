# Checklist Filtering by Property Type and Parent-Child Skip

## Problem

Users see all 89 checklist questions regardless of selected property type. Non-applicable questions (e.g., "HUG deposit waiver" for commercial properties) are marked as "참고" but still displayed, cluttering the interface. Additionally, groups of related questions (e.g., 10 tenant-related questions) all appear even when a parent question's answer makes them irrelevant.

Users report the checklist feels repetitive — too many questions asking about the same topic.

## Solution

Two-layer filtering that hides non-applicable questions from display, LLM prompts, and grade calculation:

1. **Property type filtering** — `applicable_types` field (already exists) determines which property types a question applies to
2. **Parent-child skip** — `depends_on` field (new) determines conditional visibility based on a parent question's answer

Combined with **7 question merges** to reduce total count from 89 to 82.

## Data Model Changes

### New column: `depends_on` (JSON) on `inspection_items`

```json
{ "id": "rights-003", "show_when_risk": true }
```

Meaning: show this question only when `rights-003` has `has_risk == true`.

### Parent-child relationships (2 groups, 9 child questions)

```
rights-003 (임차인 거주?) — show_when_risk: true
  ├── rights-016 (대항력 판단)
  ├── rights-015 (임차권/전세권 소멸)
  ├── rights-006 (배당요구 신청)
  ├── rights-009 (HUG 확약서)
  ├── rights-010 (미배당 보증금)
  ├── rights-014 (보증금 정보 확인)
  ├── rights-012 (임차권등기 + 새 전입)
  └── rights-013 (임차권 등기 설정)

rights-008 (선순위 세금 압류?) — show_when_risk: true
  └── rights-017 (압류 간격 1년+)
```

**Unanswered parent (has_risk: nil)**: show child questions (conservative — unconfirmed items stay visible).

### Question merges (89 → 82)

| Deleted ID | Absorbed into | Reason |
|------------|---------------|--------|
| eviction-007 | eviction-003 | Near-identical: both ask "공실이거나 명도 수월?" |
| rights-011 | rights-002 | Same document (매각물건명세서 비고란), rights-011 is a subset |
| market-004 | market-001 | Both check 실거래 activity, different time horizons |
| market-011 | inspect-011 | Both ask "수익 계산 완료?", market-011 is the result |
| regulation-001 | inspect-011 | "시세 이하 매입 가능?" overlaps with profitability calc |
| resale-002 | inspect-014 | inspect-014 already covers 주차 + 건물간격 |
| property-008 | inspect-014 | inspect-014 already covers 뻥뷰/조망 |
| finance-004 | tax-002 | Both ask about 매매사업자 명의 |

When merging, absorb the deleted item's `description` and `logic` content into the surviving item.

## Filtering Logic

### InspectionItem model

```ruby
# Static filter — SQL-level, based on property type
scope :applicable_for_type, ->(property_type) {
  return all if property_type.blank?
  # SQLite: use json_each; PostgreSQL: use ? operator
  where("applicable_types IS NULL OR EXISTS (SELECT 1 FROM json_each(applicable_types) WHERE json_each.value = ?)", property_type)
}

# Instance method — checks both filters
def visible_for?(property_type:, answered_results: {})
  applicable_for?(property_type) && !skip_for?(answered_results)
end

# Dynamic filter — Ruby-level, based on parent answer
def skip_for?(answered_results_by_code)
  return false if depends_on.blank?

  parent_code = depends_on["id"]
  parent_result = answered_results_by_code[parent_code]

  # Unanswered parent → show (conservative)
  return false if parent_result.nil? || parent_result.has_risk.nil?

  # Skip when parent's has_risk doesn't match condition
  parent_result.has_risk != depends_on["show_when_risk"]
end
```

Two-stage design:
- **Stage 1 (static)**: `applicable_types` — filtered at SQL query level. Property type doesn't change, so this is fixed.
- **Stage 2 (dynamic)**: `depends_on` — depends on parent answer, so filtered in Ruby after loading results.

## Affected Locations (4)

### 1. PdfPromptBuilder — LLM prompt filtering

- **First analysis**: send all items (property_type unknown yet, extracted from PDF)
- **Re-analysis**: filter by `applicable_for_type(property_type)` to send only applicable items
- `depends_on` skip is NOT applied to LLM prompts — LLM independently determines tenant presence from PDF

```ruby
# PdfAnalysisService
items = if @property&.property_type.present?
  InspectionItem.applicable_for_type(@property.property_type).ordered
else
  InspectionItem.ordered
end
```

### 2. TabsController#edit — display filtering

```ruby
@results = @property.inspection_results
  .where(user: current_user)
  .joins(:inspection_item)
  .where(inspection_items: { tab: InspectionItem.tabs[@tab_key] })
  .includes(:inspection_item)
  .order("inspection_items.tab_position")

property_type = @property.property_type
answered = @results.index_by { |r| r.inspection_item.code }
@results = @results.select do |r|
  r.inspection_item.visible_for?(property_type: property_type, answered_results: answered)
end
```

### 3. InspectionTabsComponent — tab counts

`load_tab_stats` must apply the same filtering. Hidden questions are excluded from both `checked` and `total` counts.

### 4. InspectionRatingService — grade calculation

```ruby
results = @property.inspection_results.where(user: @user).includes(:inspection_item)
answered = results.index_by { |r| r.inspection_item.code }
visible = results.select do |r|
  r.inspection_item.visible_for?(property_type: @property.property_type, answered_results: answered)
end
# Calculate grade from visible results only
```

Hidden questions' `has_risk` values do NOT affect the grade — they are not applicable to this property.

## Impact Summary

### Before (apartment example)
- 89 questions shown, including "분묘기지권", "상가 가시성", etc.
- All 10 tenant questions shown even when no tenant exists
- Grade based on all 89 items

### After (apartment example)
- ~70 questions shown (19 filtered by `applicable_types`)
- If no tenant → 8 more hidden (depends_on skip)
- Effective: ~62 questions for a clean apartment with no tenants
- Grade based only on visible items

### Question count reduction
- 89 → 82 (7 merges)
- 82 → ~70 per property type (applicable_types filtering, varies by type)
- ~70 → ~62 dynamically (depends_on skip when conditions met)
