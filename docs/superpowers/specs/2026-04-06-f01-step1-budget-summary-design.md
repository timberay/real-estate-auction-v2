# F01 Step1 Budget Summary — Design Spec

## Context

When users revisit the onboarding wizard (step1), they currently see only the input form with no indication of any prior calculation. Users who have already completed the budget calculation should see their previous results at a glance before re-entering values. Users who haven't calculated yet should see the same layout with empty placeholders, establishing a consistent visual pattern.

## What We're Building

A read-only **BudgetSummaryComponent** (ViewComponent) displayed at the top of the onboarding step1 screen, showing 4 key budget metrics in a horizontal grid.

## Component: BudgetSummaryComponent

### Props

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `setting` | `BudgetSetting` or `nil` | No | The user's current budget setting |

### Two States

**Calculated** (`setting.max_bid_amount` present):
- Blue tinted background (`bg-blue-50 dark:bg-blue-900/20`)
- Solid border (`border border-blue-200 dark:border-blue-800`)
- Real values displayed with `number_with_delimiter` formatting

**Uncalculated** (`setting` nil or `max_bid_amount` nil):
- Gray background (`bg-slate-50 dark:bg-slate-800`)
- Dashed border (`border border-dashed border-slate-300 dark:border-slate-600`)
- All values show `—` (em dash)

### Displayed Metrics (4-column grid)

| Position | Label | Value source | Format |
|----------|-------|-------------|--------|
| 1 | 최대입찰가 | `setting.max_bid_amount` | `N,NNN만원` (bold, blue) |
| 2 | 유용자금 | `setting.available_cash` | `N,NNN만원` |
| 3 | 예비비 합계 | `setting.total_reserves` | `N,NNN만원` |
| 4 | 대출비율 | `setting.loan_ratio` | `NN%` |

### Responsive Behavior

- Desktop (≥640px): 4-column grid (`grid-cols-4`)
- Mobile (<640px): 2x2 grid (`grid-cols-2`)

## Changes Required

### New Files

1. `app/components/budget_summary_component.rb` — Component class with `calculated?` helper
2. `app/components/budget_summary_component.html.erb` — Template with conditional styling

### Modified Files

3. `app/views/onboardings/step1.html.erb` — Add `<%= render BudgetSummaryComponent.new(setting: @setting) %>` inside `<turbo-frame>`, above the existing `WizardStepComponent`

### No Controller Changes

`OnboardingsController#step1` already loads `@setting` via `find_or_initialize_budget_setting`. The component receives this directly — no additional query needed.

## Behavior Rules

- Component is **read-only** — no click handlers, no interactivity
- Uses existing `number_with_delimiter` Rails helper for formatting
- `total_reserves` is already computed by `BudgetSetting` model (sum of 5 reserve fields)
- Dark mode support follows existing project Tailwind conventions

## Testing

- Unit test: `BudgetSummaryComponent` renders correctly in both states (calculated vs uncalculated)
- Unit test: responsive grid classes are present
- Integration test: step1 page renders the summary component with correct data
