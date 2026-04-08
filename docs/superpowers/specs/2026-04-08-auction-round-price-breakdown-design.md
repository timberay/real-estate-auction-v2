# Auction Round Price Breakdown in Budget Settings

## Summary

When the user adjusts the failed auction round slider on the budget settings screen (onboarding step 3), display a round-by-round price breakdown table below the "현재 최대입찰가" (current max bid price) area. The table updates dynamically as the user changes LTV or failed auction round values.

## Context

The budget settings screen already calculates and displays `maxBid` based on available cash, reserves, and loan ratio. The `appraisal_limits_by_round` helper exists server-side but is not used on this screen. Users need to understand how the appraisal price reduces through each failed auction round to arrive at the displayed max bid price.

## Design

### Layout: Round Breakdown Table

A card-style container appears below the max bid price display, showing:

1. **Header line**: "{N}회차 기준" (or "신건 기준" for round 0)
2. **Row: 감정가** — the calculated appraisal price upper bound
3. **Rows: each round's 최저입찰가** — from round 1 to the selected round
4. **Current round row highlighted in blue** — this equals the max bid price

### Calculation

All values derived client-side in the existing `loan-slider` Stimulus controller:

```
appraisal_price = maxBid / (0.8 ^ rounds)
round_N_min_bid = appraisal_price * (0.8 ^ N)
```

Where `maxBid = floor((available_cash - total_reserves) / (1 - loan_ratio))`

### Display by Round Setting

| Round | Rows shown |
|-------|-----------|
| 0 (신건) | 감정가 = maxBid (highlighted) |
| 1 | 감정가, 1회 유찰 최저가 (highlighted) |
| 2 | 감정가, 1회 최저가, 2회 최저가 (highlighted) |
| 3 | 감정가, 1회 최저가, 2회 최저가, 3회 최저가 (highlighted) |

### Dynamic Behavior

- Table regenerates on every change to: LTV slider, loan policy radio, or failed auction round slider
- All calculation happens client-side in `loan-slider` Stimulus controller
- Price formatting uses the same `formatPrice` JS function already used for max bid display

## Implementation Scope

1. **ERB**: Add a target container div in step3 view, inside the max bid preview card
2. **Stimulus**: Add `renderRoundBreakdown()` method to `loan-slider` controller, called from the existing `calculate()` method
3. **Styling**: Dark theme card with `bg-slate-800` border `border-slate-700`, consistent with existing UI

## Out of Scope

- Server-side rendering of this table (all client-side)
- Persisting round breakdown data to the database
- Showing this table on other screens (budget snapshots, inspection detail)
