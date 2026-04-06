# Property List Budget Badge — Inline Max Bid Display

## Problem

Users cannot see their budget information while browsing the property list. They must navigate to `/settings/budget` to check their max bid amount, breaking their browsing flow.

## Decision

Add a clickable inline badge next to the "물건 목록" page title showing the max bid amount. The badge links to `/settings/budget` for full budget details or setup.

## Design

### Badge States

| State | Condition | Style | Content |
|-------|-----------|-------|---------|
| Calculated | `budget_setting.max_bid_amount` present | Blue bg (`bg-blue-50`), solid border (`border-blue-200`) | "최대입찰가" label + formatted amount (e.g., "2.5억") + chevron-right icon |
| Not set | `budget_setting` nil or `max_bid_amount` nil | Gray bg (`bg-slate-50`), dashed border (`border-dashed border-slate-300`) | "예산 미설정" text + chevron-right icon |

Both states link to `settings_budget_path`.

### Layout

The page title row changes from a single `<h1>` to a flex row with the badge on the right:

```
┌─────────────────────────────────────────────┐
│ 물건 목록              최대입찰가 2.5억  >  │
└─────────────────────────────────────────────┘
```

On mobile, the badge wraps below the title (flex-wrap or flex-col on small screens).

### Tailwind Classes

**Calculated state badge:**
```
inline-flex items-center gap-1.5 rounded-md
bg-blue-50 dark:bg-blue-900/20
border border-blue-200 dark:border-blue-800
px-3 h-8 text-sm
hover:bg-blue-100 dark:hover:bg-blue-800/30
transition-colors duration-150
```

**Not-set state badge:**
```
inline-flex items-center gap-1.5 rounded-md
bg-slate-50 dark:bg-slate-800
border border-dashed border-slate-300 dark:border-slate-600
px-3 h-8 text-sm
hover:bg-slate-100 dark:hover:bg-slate-700
transition-colors duration-150
```

**Label text:** `text-xs text-slate-500 dark:text-slate-400`
**Amount text:** `text-sm font-bold tabular-nums text-blue-700 dark:text-blue-300`
**Not-set text:** `text-xs text-slate-400 dark:text-slate-500`
**Chevron icon:** `w-3.5 h-3.5 text-slate-400 dark:text-slate-500`

### Data Access

`PropertiesController#index` already accesses `current_user.budget_setting` (for `@max_bid_amount`). No new controller changes needed — the view reads `current_user.budget_setting` directly, consistent with the existing pattern.

### Price Formatting

Use the existing `format_price_in_eok` helper which formats amounts in Korean 억/만원 units.

## Changes Required

| File | Change |
|------|--------|
| `app/views/properties/index.html.erb` | Replace title `<h1>` with flex row containing title + budget badge link |

No new components, controllers, or models needed.

## Out of Scope

- Full budget summary (4-item grid) on property list — decided against for brevity
- Collapsible/expandable budget panel
- Budget editing from property list page
