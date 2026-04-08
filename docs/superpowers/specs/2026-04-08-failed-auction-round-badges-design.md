# Failed Auction Round Badges on Analysis Screen

## Problem

The analysis screen header shows the user's max bid amount, but ignores the failed auction round setting. When a user is willing to wait for N rounds of failed auctions, they can target properties with higher appraisal prices — but this information isn't visible during property analysis.

## Solution

Add per-round badges next to the existing max bid badge in the shared inspection layout header. Each badge shows the maximum appraisal price targetable at that failed auction round.

## Display Rules

- **Location:** `app/views/inspections/_layout.html.erb` — top-right badge area, after the existing 최대입찰가 badge
- **Source data:** `current_user.budget_setting` — `max_bid_amount` and `failed_auction_rounds`
- **Condition:** Only show round badges when `failed_auction_rounds >= 1`
- **Count:** One badge per round, from 1 up to the user's `failed_auction_rounds` setting

## Badge Design

### Existing badges (unchanged)
- 감정가: amber background (`bg-amber-50 dark:bg-amber-900/20`)
- 최저매각가: amber background
- 최대입찰가: blue background (`bg-blue-50 dark:bg-blue-900/20`) — links to budget settings

### New round badges
- **Color:** Green/emerald (`bg-emerald-50 dark:bg-emerald-900/20`, border `border-emerald-200 dark:border-emerald-800`)
- **Label text:** `1회`, `2회`, `3회` (in `text-emerald-600 dark:text-emerald-400`)
- **Value text:** formatted via `format_price_in_eok` (in `text-emerald-700 dark:text-emerald-300`, bold, tabular-nums)
- **Link:** Same as 최대입찰가 — links to budget settings page (`settings_budget_path`)

### Layout example

```
[감정가 2억] [최저매각가 1.6억] [최대입찰가 1.2억] [1회 1.5억] [2회 1.875억]
```

When `failed_auction_rounds == 0`: only the existing three badges shown (no change).

## Calculation

Per-round appraisal limit uses the existing formula from `BudgetCalculationService`:

```
round_limit(N) = floor(max_bid_amount / 0.8^N)
```

- 0회 (신건): `max_bid_amount` (existing badge)
- 1회: `floor(max_bid_amount / 0.8)` = max_bid_amount × 1.25
- 2회: `floor(max_bid_amount / 0.64)` = max_bid_amount × ~1.5625
- 3회: `floor(max_bid_amount / 0.512)` = max_bid_amount × ~1.953

Calculation done inline in the view (simple arithmetic, no service call needed).

## Responsive Behavior

The badge container already uses `flex-wrap`, so additional badges wrap naturally on smaller screens. No additional responsive handling required.

## Files to Change

- `app/views/inspections/_layout.html.erb` — add round badge loop after existing 최대입찰가 badge

No model, controller, or service changes needed.
