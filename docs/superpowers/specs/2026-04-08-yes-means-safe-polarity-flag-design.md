# Yes-Means-Safe Polarity Flag

## Problem

The checklist display system has a hardcoded assumption: "Yes" always means safe (green) and "No" always means danger (red). This is encoded in `selected_answer`, logic highlight colors, and manual radio button values.

However, 19 questions are phrased where "Yes" indicates danger (e.g., "전입신고된 제3자 임차인이 거주하고 있습니까?" — answering "Yes" means a risky tenant exists). For these questions:

- Auto-detected `has_risk: true` highlights "No" in red instead of "Yes"
- Manual "예" selection sets `has_risk: false` (safe), displaying a green border for a dangerous condition
- The logic section highlights the wrong row with the wrong color

## Solution

Add a `yes_means_safe` boolean column to `inspection_items` (default: `true`). When `false`, the display mapping inverts — "Yes" becomes the danger answer (red) and "No" becomes the safe answer (green).

The `has_risk` boolean semantics remain unchanged (true = danger exists). Only the **display mapping** between Yes/No labels and safe/danger colors changes per question.

## Data Model

### Migration

Add to `inspection_items`:

```ruby
t.boolean :yes_means_safe, null: false, default: true
```

### Affected Questions (yes_means_safe: false)

| ID | Question Summary |
|---|---|
| rights-011 | 유치권/법정지상권 기재가 있습니까? |
| rights-003 | 전입신고된 제3자 임차인이 거주하고 있습니까? |
| rights-010 | 대항력 있는 임차인의 미배당 보증금이 있습니까? |
| rights-016 | 말소기준일 이전 대항력 있는 임차인이 있습니까? |
| rights-020 | 현황조사서에 유치권 신고 표시가 있습니까? |
| property-002 | 벽체 구분 불명확/불법 구조변경이 있습니까? |
| rights-001 | 선순위 가처분이 있습니까? |
| rights-004 | 선순위 가등기가 있습니까? |
| rights-007 | 예고등기가 있습니까? |
| rights-008 | 선순위 세금 압류가 있습니까? |
| rights-012 | 선순위 임차권 등기/미상 임차인이 있습니까? |
| rights-022 | 질권 표시가 있습니까? |
| rights-021 | 전세사기 우선매수권 행사 가능성이 있습니까? |
| inspect-001 | 감정평가서에 중대한 문제가 기재되어 있습니까? |
| tax-005 | 인구 감소 지역이면서 공시가격이 4억 원 이상입니까? |
| eviction-001 | 화재·누수·크랙 등 치명적 하자가 있습니까? |
| exit-001 | 집 내부에 악취나 환기 문제가 있습니까? |
| inspect-013 | 누수 흔적이 있습니까? |
| manual-001 | 토지에 분묘기지권이 있습니까? |

All other questions remain `yes_means_safe: true` (default).

## Display Logic Changes

### selected_answer (InspectionItemComponent)

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

### Logic Highlight Colors

Color assignment depends on both `selected_answer` and `yes_means_safe`:

| selected_answer | yes_means_safe | Color |
|---|---|---|
| "yes" | true | Green (safe) |
| "yes" | false | Red (danger) |
| "no" | true | Red (danger) |
| "no" | false | Green (safe) |

Rule: the selected answer gets the **safe color (green) if it means safe, danger color (red) if it means danger**. The unselected answer is always dimmed.

This applies to both server-rendered ERB and the Stimulus controller's `#updateLogicHighlight`.

### Manual Radio Buttons

The radio button values for "예"/"아니오" depend on the flag:

| yes_means_safe | "예" (Yes) value | "아니오" (No) value |
|---|---|---|
| true | `has_risk: false` | `has_risk: true` |
| false | `has_risk: true` | `has_risk: false` |

### Stimulus Controller

Pass `yes_means_safe` as a Stimulus value via data attribute:

```html
data-inspection-item-yes-means-safe-value="<%= @item.yes_means_safe? %>"
```

The controller uses this to determine color assignment in `#updateLogicHighlight`.

## What Does NOT Change

- `has_risk` boolean semantics (true = danger exists)
- `DETECTION_RULES` in `InspectionRunner` — detection logic unchanged
- `risk_classes` — border color depends only on `has_risk`
- `status_text` — "안전"/"위험" depends only on `has_risk`
- `InspectionRatingService` — aggregation logic unchanged

## Files to Modify

| File | Change |
|---|---|
| New migration | Add `yes_means_safe` boolean column |
| `db/seeds/checklist_items_summary.json` | Add `"yes_means_safe": false` to 15 items |
| Seed loader | Include `yes_means_safe` in attribute mapping |
| `app/components/inspection_item_component.rb` | Update `selected_answer`, add color helper |
| `app/components/inspection_item_component.html.erb` | Dynamic logic highlight colors, radio button value branching |
| `app/javascript/controllers/inspection_item_controller.js` | Add `yesMeansSafe` value, update `#updateLogicHighlight` |
| Component tests | Verify both polarities render correct colors |

## Testing Strategy

- Unit test `selected_answer` for both `yes_means_safe: true` and `false` with all `has_risk` states (`true`, `false`, `nil`)
- Component render test: verify correct CSS classes for logic rows in both polarities
- Integration test: verify manual radio button submission sets correct `has_risk` value for inverted questions
