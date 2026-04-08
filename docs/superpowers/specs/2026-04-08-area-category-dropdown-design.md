# Area Category Dropdown Design

**Date:** 2026-04-08
**Status:** Approved

## Problem

The current area input uses free-text number fields with a 평/㎡ unit toggle. This requires users to know exact square meter or pyeong values. A category-based dropdown selection aligned with standard Korean apartment size classifications is more intuitive.

## Decision

Replace free-text number inputs with two dropdown selects (min/max) using predefined Korean apartment size categories. Remove the 평/㎡ unit toggle entirely — both units are displayed together in each option label.

## Area Categories

| Category | Korean Label | Pyeong Range | ㎡ Range | DB Value (min) | DB Value (max) |
|----------|-------------|-------------|---------|----------------|----------------|
| 소형 (초소형) | 소형 (10~15평 / ~40㎡) | 10~15평 | ~40㎡ | 0 | 40 |
| 중소형 | 중소형 (20~25평 / 40~60㎡) | 20~25평 | 40~60㎡ | 40 | 60 |
| 중형 · 국평 | 중형 · 국평 (30~34평 / 60~85㎡) | 30~34평 | 60~85㎡ | 60 | 85 |
| 중대형 | 중대형 (38~42평 / 85~102㎡) | 38~42평 | 85~102㎡ | 85 | 102 |
| 대형 | 대형 (45평~ / 102㎡~) | 45평~ | 102㎡~ | 102 | 150 |

- **Min dropdown** stores the category's lower bound in ㎡: 0, 40, 60, 85, 102
- **Max dropdown** stores the category's upper bound in ㎡: 40, 60, 85, 102, 150

## DB Storage

- **Columns retained:** `area_range_min` (integer, ㎡), `area_range_max` (integer, ㎡)
- **Column removed:** `area_unit` (string) — no longer needed since both units are displayed in labels
- Values continue to be stored as integers in ㎡, maintaining full compatibility with existing snapshots and display logic

## UI Changes

### Dropdown Labels

**Min dropdown (면적 최소):**
- 소형 (10~15평 / ~40㎡) → saves 0
- 중소형 (20~25평 / 40~60㎡) → saves 40
- 중형 · 국평 (30~34평 / 60~85㎡) → saves 60
- 중대형 (38~42평 / 85~102㎡) → saves 85
- 대형 (45평~ / 102㎡~) → saves 102

**Max dropdown (면적 최대):**
- 소형 (10~15평 / ~40㎡) → saves 40
- 중소형 (20~25평 / 40~60㎡) → saves 60
- 중형 · 국평 (30~34평 / 60~85㎡) → saves 85
- 중대형 (38~42평 / 85~102㎡) → saves 102
- 대형 (45평~ / 102㎡~) → saves 150

### Validation

- **Model:** `area_range_min <= area_range_max`
- **Frontend (Stimulus):** When min dropdown changes, disable max options that are smaller than the selected min category. When max changes, disable min options larger than the selected max category.

## Affected Files

### Remove
- `app/javascript/controllers/area_unit_controller.js` — unit toggle no longer needed

### Modify
- `app/views/onboardings/step2.html.erb` — replace number fields + unit toggle with two select dropdowns
- `app/views/settings/budgets/show.html.erb` — same replacement
- `app/models/budget_setting.rb` — remove `convert_area_to_sqm!`, `display_area_min/max`, `SQM_PER_PYEONG`, `area_unit` validation; add min≤max validation
- `app/controllers/onboardings_controller.rb` — remove `area_unit` from params, remove `convert_area_to_sqm!` call, update defaults
- `app/controllers/settings/budgets_controller.rb` — remove `area_unit` from params, remove `convert_area_to_sqm!` call
- `app/javascript/controllers/reserve_fund_controller.js` — remove unit conversion logic, read dropdown values directly
- `app/services/budget_snapshot_service.rb` — verify snapshot formatting still works (should be fine, values remain ㎡ integers)
- `db/migrate/` — new migration to remove `area_unit` column

### Verify (no changes expected)
- `app/views/settings/budget_snapshots/show.html.erb` — snapshot display uses ㎡ directly
- `app/views/settings/budget_snapshots/compare.html.erb` — comparison view
- Test files — update to reflect new dropdown-based inputs and removed unit logic

## Default Values

- Onboarding step2 defaults: min=60 (중형 · 국평), max=85 (중형 · 국평) — the most popular "국민평수" category pre-selected
