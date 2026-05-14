# Remove Failed Auction Rounds Feature

## Problem

The current budget system includes `failed_auction_rounds` (0–3) and `searchable_appraisal_limit` — a reverse-calculated appraisal ceiling based on the user's max bid and a target round of failure.

This feature assumes users search for properties by appraisal price range, targeting properties that might become affordable after N failed rounds. However, the actual user flow is:

1. User enters a specific case number (경매번호)
2. System fetches property data via API/crawling — including the **current** `min_bid_price` and auction round info already set by the court
3. User compares their `max_bid_amount` against the property's `min_bid_price`

The court publishes the current minimum bid price for each auction. The app does not need to pre-calculate round-based prices or maintain a "target round" strategy. The `0.8^N` reduction formula is also an assumption — actual court reduction rates can vary.

## Decision

Remove `failed_auction_rounds` and `searchable_appraisal_limit` from the entire codebase. The budget system retains `max_bid_amount` as the single core metric.

## Scope

### Remove

| Layer | File | Change |
|-------|------|--------|
| Service | `app/services/budget_calculation_service.rb` | Remove `PRICE_REDUCTION_PER_ROUND`, `failed_auction_rounds` param, `searchable_appraisal_limit` calculation. Return only `total_reserves`, `max_bid_amount`, `breakdown`. |
| Service | `app/services/budget_snapshot_service.rb` | Remove from `COMPARABLE_FIELDS`, `NUMERIC_FIELDS`, and field assignments in `create()`/`recalculate()`. |
| Model | `app/models/budget_setting.rb` | Remove `failed_auction_rounds` validation (lines 9–11). |
| Controller | `app/controllers/onboardings_controller.rb` | Remove `failed_auction_rounds` from service call (line 63), `searchable_appraisal_limit` assignment (line 67), and `step3_params` (line 101). |
| Controller | `app/controllers/settings/budgets_controller.rb` | Remove from service call (line 30), result assignment (line 34), and `budget_params` (line 58). |
| Helper | `app/helpers/application_helper.rb` | Delete `appraisal_limits_by_round` method (lines 26–35). |
| JS | `app/javascript/controllers/loan_slider_controller.js` | Remove targets (`roundsSlider`, `roundsDisplay`, `limitPreview`, `roundBreakdown`), `slideRounds()`, round calculation in `updateAll()`, `renderRoundBreakdown()`, `#breakdownRow()`. Keep LTV slider + max bid preview only. |
| JS | `app/javascript/controllers/failed_rounds_controller.js` | Delete entire file (orphaned, no usage). |
| View | `app/views/onboardings/step3.html.erb` | Remove round breakdown container (line 64), round slider section (lines 66–79), appraisal limit preview card (lines 81–84). Update description text (line 4). |
| View | `app/views/settings/budgets/show.html.erb` | Remove "유찰 회차" input field (lines 91–93). Change `grid-cols-2` to single column. |
| View | `app/views/inspections/_layout.html.erb` | Remove round badges loop (lines 25–31). |
| View | `app/views/onboardings/complete.html.erb` | Remove conditional round info block (lines 13–20). |
| View | `app/views/settings/budget_snapshots/show.html.erb` | Remove "유찰 회차" and "검색 가능 감정가" rows (lines 41–42). |
| View | `app/views/settings/budget_snapshots/compare.html.erb` | Remove from `field_labels` hash (lines 38–39). |
| DB | New migration | Drop `failed_auction_rounds` and `searchable_appraisal_limit` from `budget_settings` and `budget_snapshots` tables. |
| Test | `test/system/onboarding_round_breakdown_test.rb` | Delete entire file. |
| Test | `test/helpers/application_helper_test.rb` | Delete `appraisal_limits_by_round` tests (lines 40–71). |
| Test | All other test files | Remove `failed_auction_rounds` and `searchable_appraisal_limit` references from params, fixtures, and assertions. |
| Docs | `docs/superpowers/specs/2026-04-08-auction-round-price-breakdown-design.md` | Delete. |
| Docs | `docs/superpowers/specs/2026-04-08-failed-auction-round-badges-design.md` | Delete. |
| Docs | `docs/superpowers/plans/2026-04-08-auction-round-price-breakdown.md` | Delete. |
| Docs | `docs/superpowers/plans/2026-04-08-failed-auction-round-badges.md` | Delete. |
| Docs | `docs/superpowers/specs/2026-04-05-f01-onboarding-budget-design.md` | Update — remove round-related sections. |
| Docs | `docs/superpowers/specs/2026-04-05-srs-design.md` | Update — remove round references from F01 and glossary. |

### Keep (unchanged)

- `BudgetSetting.max_bid_amount` — core budget metric
- `Property.min_bid_price`, `Property.appraisal_price` — court-provided data
- LTV slider and max bid preview in onboarding step 3
- Budget calculator controller (`budget_calculator_controller.js`) — only calculates max bid
- All loan policy selection UI
- Budget summary component and stat card component
- Snapshot versioning, comparison, and recalculation (minus the two removed fields)

## Verification

1. `bin/rails test` — all tests pass
2. `bin/rubocop` — no style violations
3. `bin/rails db:migrate` — migration runs cleanly
4. Manual: complete onboarding flow (step 1→2→3→complete) — no round UI, max bid displays correctly
5. Manual: edit budget in settings — no round input, save works
6. Manual: view snapshot show/compare — no round fields displayed
7. Manual: inspection layout header — only 감정가, 최저매각가, 최대입찰가 badges (no round badges)
