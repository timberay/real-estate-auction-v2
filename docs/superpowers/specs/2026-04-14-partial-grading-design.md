# Partial Grading Design

**Date:** 2026-04-14
**Status:** Draft

## Problem

The current grading system requires users to answer ALL checklist items before evaluating safety. This blocks users from getting feedback until every question is completed. Users want incremental feedback as they work through tabs.

## Decisions

1. **Partial evaluation** — grade based on answered items only; unanswered items are ignored
2. **Save triggers evaluation** — clicking "저장하기" immediately evaluates the tab and updates the overall grade
3. **Unanswered indicator** — show unanswered count via tab navigation badge (persistent) + post-save banner (transient)
4. **Final judgment sync** — saving a tab updates `UserProperty.safety_rating` so the 종합판정 page loads the latest data on next visit
5. **Save always enabled** — save button is always active regardless of completion; zero answers results in "미평가" status
6. **Backend-only sync** — no Turbo Stream for cross-tab updates; 종합판정 page loads fresh data on navigation

## Scope

### In Scope

- `InspectionRatingService` logic change
- `unified_form_controller.js` save button validation removal
- `TabsController#update` post-save rating calculation + flash
- `InspectionTabsComponent` unanswered badge
- `tabs/edit.html.erb` post-save result banner
- `GradeSummaryComponent` `:incomplete` semantics update

### Out of Scope

- Turbo Stream real-time updates
- New service objects or architectural changes
- UI redesign beyond the specified indicators

## Design

### 1. InspectionRatingService

**File:** `app/services/inspection_rating_service.rb`

#### `call` method change

Current behavior:
```ruby
return :incomplete if results.exists?(has_risk: nil)
```

New behavior:
```ruby
answered = results.where.not(has_risk: nil)
return :incomplete if answered.empty?

# Evaluate based on answered items only
if answered.exists?(has_risk: true, resolvable: false)
  :danger
elsif answered.exists?(has_risk: true)
  :caution
else
  :safe
end
```

`:incomplete` now means "zero answered items" (previously meant "any unanswered item exists").

#### `tab_rating(tab_key)` method

Same logic change applied at tab scope — evaluate only answered items within the tab.

### 2. Save Button (unified_form_controller.js)

**File:** `app/javascript/controllers/unified_form_controller.js`

- Remove the validation logic that disables the submit button when manual items are unanswered
- Keep the progress counter display (`completed/total`) as informational only
- Submit button is always enabled

### 3. TabsController#update Post-Save Flow

**File:** `app/controllers/inspections/tabs_controller.rb`

After saving individual results (existing logic), add:

```ruby
# After result updates — reuse single service instance for both calls
rating_service = InspectionRatingService.new(property: @property, user: current_user)
overall_rating = rating_service.call
tab_rating = rating_service.tab_rating(@tab_key)

tab_results = @property.inspection_results
  .joins(:inspection_item)
  .where(inspection_items: { tab: @tab_key }, user: current_user)
unanswered_count = tab_results.where(has_risk: nil).count

tab_label = TabSummaryTableComponent::TAB_LABELS[@tab_key] || @tab_key

flash[:tab_rating] = {
  "rating" => tab_rating.to_s,
  "label" => tab_label,
  "unanswered_count" => unanswered_count
}
```

### 4. Post-Save Result Banner

**File:** `app/views/inspections/tabs/edit.html.erb`

Add banner at top of page (after `<div id="top">`), rendered when `flash[:tab_rating]` is present:

```
┌─────────────────────────────────────────────────────┐
│ [🟢 안전]  물건분석 평가 완료 — 미응답 7개          │
└─────────────────────────────────────────────────────┘
```

- Rating badge uses existing color scheme (green/yellow/red/gray)
- Unanswered count shown only when > 0
- Banner disappears on next navigation (standard flash behavior)

### 5. Tab Navigation Unanswered Badge

**File:** `app/components/inspection_tabs_component.rb` + `.html.erb`

Add unanswered count badge next to existing `checked/total` counter:

```
[🟢 안전] 물건분석 5/12  ⟨7⟩
                          ↑ amber badge, only when:
                            - tab has been saved at least once (tab_rating != nil/incomplete)
                            - unanswered > 0
```

Display conditions:
- Tab has at least one answered item (tab_rating is not `:incomplete`)
- Unanswered items exist (`total - checked > 0`)

When all items are answered, the badge disappears and only the existing counter remains.

**N+1 query prevention:** `InspectionTabsComponent` already calls `tab_counts` per tab which issues individual queries. The existing `tab_rating` calls also query per tab. To avoid N+1, the implementation should batch-load all tab statistics in a single grouped query during `initialize` and cache the results, rather than querying per-tab in the loop.

### 6. GradeSummaryComponent Semantics

**File:** `app/components/grade_summary_component.rb`

`:incomplete` display changes:
- **Current:** "분석 미완료" — shown when any unanswered item exists
- **New:** "미평가" — shown only when zero items are answered across all tabs

The component should also show progress info: "5개 중 3개 탭 분석 완료" alongside the overall grade when not all tabs have been evaluated.

**Partial evaluation visual distinction:** When the grade is based on partial data (not all tabs fully answered), the grade badge should be visually differentiated from a fully-completed evaluation:
- Append "(진행 중)" to the grade label — e.g., "안전 (진행 중)" vs "안전"
- Use reduced opacity (e.g., `opacity-75`) on the badge to subtly indicate incomplete status
- This prevents users from mistaking a partial "안전" for a fully-evaluated "안전"

Fully evaluated = all `inspection_results` for this property+user have `has_risk != nil`.

### 7. Data Flow Summary

```
User edits tab → clicks 저장하기
  → TabsController#update
    → Save individual results (existing)
    → InspectionRatingService.call() → updates UserProperty.safety_rating
    → Calculate tab_rating + unanswered_count
    → Set flash[:tab_rating]
    → Redirect to same tab
  → Tab edit page renders:
    → Post-save banner (from flash)
    → Tab navigation badges (from DB)

User clicks 종합판정 tab
  → GradesController#show
    → Loads latest UserProperty.safety_rating
    → All components render with current data
    → No additional changes needed
```

## Files to Modify

| File | Change |
|------|--------|
| `app/services/inspection_rating_service.rb` | Partial evaluation logic |
| `app/javascript/controllers/unified_form_controller.js` | Remove save button disable logic |
| `app/controllers/inspections/tabs_controller.rb` | Post-save rating + flash |
| `app/views/inspections/tabs/edit.html.erb` | Post-save result banner |
| `app/components/inspection_tabs_component.rb` | Unanswered count data |
| `app/components/inspection_tabs_component.html.erb` | Unanswered badge rendering |
| `app/components/grade_summary_component.rb` | `:incomplete` semantics |
| `app/components/grade_summary_component.html.erb` | Progress info display |

## Testing Strategy

- **Unit:** `InspectionRatingService` — test partial answers return correct grades
- **Unit:** `InspectionTabsComponent` — test unanswered badge rendering logic
- **Integration:** `TabsController#update` — test flash contains rating info after save
- **Integration:** Save with zero answers → verify `:incomplete` / "미평가" status
- **Integration:** Save with partial answers → verify correct grade calculated
