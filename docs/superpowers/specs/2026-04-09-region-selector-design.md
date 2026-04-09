# Region Selector Dropdown Design

**Date:** 2026-04-09
**Status:** Draft

## Overview

Add a region selection `<select>` dropdown to three screens so users can choose their target auction region. The dropdown auto-saves on change via a lightweight PATCH request — no form submission required.

## Data Source

- `BudgetSetting::REGIONS` — 19 Korean regions (already defined in model)
- `BudgetSetting::DEFAULT_REGION` — "제주특별자치도"
- `BudgetSetting#region` column — already exists with `inclusion` validation
- `BudgetSetting#effective_region` — returns `region || DEFAULT_REGION`

No model or migration changes needed.

## Target Screens

### 1. Onboarding Step 1 (`app/views/onboardings/step1.html.erb`)

- **Position:** Above the 유용자금 input, inside the existing form
- **Behavior:** On change, auto-saves region via dedicated endpoint. Also included in the Step 1 form params so it persists on form submit.
- **Default:** "제주특별자치도" (from `effective_region`)

### 2. Budget Settings (`app/views/settings/budgets/show.html.erb`)

- **Position:** New `CardComponent` titled "관심 지역", placed above the "유용자금" card (first card in the form)
- **Behavior:** On change, auto-saves region. Also included in the form's permitted params so it persists on full form save.
- **Default:** Current saved region or "제주특별자치도"

### 3. Properties Index — Inline Criteria Search (`app/views/properties/index.html.erb`)

- **Position:** Above the 사건번호 input, inside the `criteria-search` controller div
- **Behavior:** On change, auto-saves region. The next criteria search will use the updated region.
- **Default:** Current saved region or "제주특별자치도"

## Auto-Save Architecture

### Endpoint

New dedicated route for single-field region update:

```
PATCH /settings/budget/region
```

Handled by `Settings::BudgetsController#update_region` — a lightweight action that updates only the `region` field without triggering budget recalculation or snapshot creation.

Response: `head :ok` on success, `head :unprocessable_entity` on validation failure.

### Stimulus Controller: `region-select`

A small Stimulus controller attached to each `<select>`:

```
data-controller="region-select"
data-region-select-url-value="/settings/budget/region"
data-action="change->region-select#save"
```

Behavior:
1. On `change`, sends `PATCH` with `{ budget_setting: { region: value } }`
2. On success: briefly shows a checkmark (✓) next to the dropdown (fade in/out over ~1s)
3. On failure: reverts the select to previous value, shows brief error indicator

### Route

```ruby
namespace :settings do
  resource :budget, only: [:show, :update] do
    member do
      patch :update_region
    end
  end
end
```

This produces: `PATCH /settings/budget/update_region` → `settings/budgets#update_region`

## UI Specification

### Select Element

Standard HTML `<select>` using the same Tailwind classes as existing selects in the project (e.g., property_type select in budget settings):

```erb
<select data-controller="region-select"
        data-region-select-url-value="<%= update_region_settings_budget_path %>"
        data-action="change->region-select#save"
        name="budget_setting[region]"
        class="w-full rounded-md border border-slate-200 dark:border-slate-600
               bg-white dark:bg-slate-700 px-3 py-2 text-sm
               text-slate-900 dark:text-slate-100
               focus:outline-none focus:ring-2 focus:ring-blue-500/20
               focus:border-blue-500">
  <% BudgetSetting::REGIONS.each do |region| %>
    <option value="<%= region %>" <%= 'selected' if region == @setting.effective_region %>>
      <%= region %>
    </option>
  <% end %>
</select>
```

### Label

- Text: "관심 지역"
- Style: Same as existing labels (`text-sm font-medium text-slate-700 dark:text-slate-300`)

### Save Feedback

- Success: Small "✓ 저장됨" text appears next to select, fades out after 1.5s
- Failure: Select reverts to previous value (no disruptive alert)

## Controller Changes

### `Settings::BudgetsController`

Add `update_region` action:

```ruby
def update_region
  @setting = current_user.budget_setting
  if @setting.update(region: params.dig(:budget_setting, :region))
    head :ok
  else
    head :unprocessable_entity
  end
end
```

Add `:region` to `budget_params` permitted list (for full form save).

### `OnboardingsController`

Add `:region` to `step1_params` permitted list.

## Stimulus Controller

**File:** `app/javascript/controllers/region_select_controller.js`

Responsibilities:
- Listen for `change` event on the select
- Send PATCH request with CSRF token
- Show success/failure feedback
- Revert value on failure

## Tests

### Controller Tests

- `Settings::BudgetsController#update_region` — saves region, returns 200
- `Settings::BudgetsController#update_region` — rejects invalid region, returns 422
- `Settings::BudgetsController#update` — persists region along with other fields
- `OnboardingsController#create_step1` — persists region along with available_cash

### Existing Tests

- Verify existing controller tests still pass with the new permitted param

## Scope Boundaries

- No new model fields or migrations (region column already exists)
- No changes to `BudgetCalculationService` or snapshot logic
- No changes to `CourtAuctionSearchService` (already uses `effective_region`)
- The dropdown is a standard `<select>` — no custom component, no search functionality
- Auto-save only for region field; other budget fields still require form submit
