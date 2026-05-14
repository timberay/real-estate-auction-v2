# F03 Unified Results Page — Source-Aware Input Logic

## Problem

The current "분석 결과 및 해결 방안" (results) page treats all risky items identically with "해결 가능/해결 불가" radio buttons. This is incorrect because:

1. **Auto-detected risk items** — API confirmed the risk exists. Asking "해결 가능/불가" (can you resolve it?) is appropriate.
2. **Manual items** — API could not detect these. The user should first confirm whether the risk exists ("예/아니오"), and only if "예" should they see "해결 가능/불가".

Additionally, the current 2-step flow (`manual_inputs` → `results`) splits this logic across two pages unnecessarily.

## Decision

Merge the `manual_inputs` step into the `results` page. Differentiate input UI by `source_type` within `ChecklistItemComponent`.

### Source Type Identification

After `AutoCheckRunner` runs:
- Auto-detected items: `source_type: "auto"`, `has_risk: true/false`
- Manual items: `source_type: nil`, `has_risk: nil`

The component uses `source_type == "auto"` vs `source_type != "auto"` (nil) to determine which input UI to render. When the user submits the unified form with a manual item answered, `ResultsController#update` sets `source_type: "manual"` along with `has_risk`.

## Design

### Card States (5 types)

| # | Source | Condition | Card Style | Input UI |
|---|--------|-----------|------------|----------|
| 1 | `auto` | `has_risk: false` | Green border | None (read-only) |
| 2 | `auto` | `has_risk: true` | Red border | "해결 가능/해결 불가" + resolution note |
| 3 | `manual` | `has_risk: nil` (unanswered) | Gray border | "예/아니오" only |
| 4 | `manual` | User selects "예" | Yellow border | "예/아니오" + dynamically revealed "해결 가능/해결 불가" + resolution note |
| 5 | `manual` | User selects "아니오" | Green border | "예/아니오" (selection preserved) |

### Dynamic Behavior

- Manual items start in state 3 (gray, unanswered).
- When user clicks "예": Stimulus controller reveals the "해결 가능/불가" sub-section with slide-down animation. Card border changes to yellow.
- When user clicks "아니오": Stimulus controller hides the sub-section (if visible) and clears any resolvable/note values. Card border changes to green.
- No server round-trip — pure client-side toggle via Stimulus.

### Status Labels

| Source | State | Badge | Label |
|--------|-------|-------|-------|
| Auto, safe | `has_risk: false` | `AUTO` (green bg) | 안전 |
| Auto, risk | `has_risk: true` | `AUTO` (red bg) | 위험 |
| Manual, unanswered | `has_risk: nil` | `직접 확인` (gray bg) | 미입력 |
| Manual, risk confirmed | user selected "예" | `직접 확인` (yellow bg) | 위험 확인 |
| Manual, safe confirmed | user selected "아니오" | `직접 확인` (green bg) | 안전 |

### Form Parameter Structure

All items submit through a single `resolutions` hash:

```ruby
{
  resolutions: {
    "<result_id>" => {
      has_risk: "true",          # manual items only (auto items omit this)
      resolvable: "true",        # present only when has_risk is true
      resolution_note: "..."     # present only when has_risk is true
    }
  }
}
```

- Auto items with `has_risk: true`: submit `resolvable` + `resolution_note`
- Auto items with `has_risk: false`: no form fields, nothing submitted
- Manual items: always submit `has_risk`. If `has_risk: true`, also submit `resolvable` + `resolution_note`

### Validation

- Submit button is disabled until all manual items have been answered ("예" or "아니오").
- For manual items answered "예", `resolvable` must also be selected before submission is allowed.
- Stimulus controller handles real-time validation state.

## Changes Required

### Delete (with impact analysis)

| File | Purpose | Dependents |
|------|---------|------------|
| `app/controllers/analyses/manual_inputs_controller.rb` | Manual input collection | Routes, integration test |
| `app/views/analyses/manual_inputs/edit.html.erb` | Manual input form | None (standalone view) |
| `app/javascript/controllers/manual_input_controller.js` | Form validation for manual inputs | Only used in `manual_inputs/edit` |
| Related routes in `config/routes.rb` | `resource :manual_input` under analyses | `StartController` redirect, link helpers |
| Related test files | Integration/controller tests for manual_inputs | None |

### Modify

| File | Change |
|------|--------|
| `app/components/checklist_item_component.rb` | Add `source_type` branching logic, new helper methods for card state |
| `app/components/checklist_item_component.html.erb` | Render different input sections based on source type |
| `app/javascript/controllers/resolution_input_controller.js` | Add manual item "예/아니오" toggle logic, form validation, card style updates |
| `app/controllers/analyses/results_controller.rb` | Handle `has_risk` updates for manual items in `#update` |
| `app/controllers/analyses/start_controller.rb` | Always redirect to `results`, remove `manual_inputs` routing |
| `config/routes.rb` | Remove `manual_input` resource |

### Verify

| File | Check |
|------|-------|
| `app/services/safety_rating_service.rb` | Ensure manual items with `has_risk: nil` (unanswered) are handled — should not happen if validation works, but guard defensively |
| `test/integration/property_analysis_flow_test.rb` | Update to reflect unified flow |

## Out of Scope

- Changes to `AutoCheckRunner` detection rules
- Changes to `SafetyRatingService` calculation logic (unless nil-guard needed)
- Changes to `ratings/show` page
- Any new models or database migrations
