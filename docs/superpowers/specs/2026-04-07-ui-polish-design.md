# UI Polish: Property Show Width, Sidebar Highlight, Price Badges

**Date:** 2026-04-07
**Status:** Approved

## Overview

Three targeted UI improvements to the inspection analysis workflow:

1. Constrain property show page width
2. Highlight active sidebar menu item on subpages
3. Add property price badges to inspection layout header

## 1. Property Show Page — Width Constraint

**Problem:** The property show page displays minimal content (case number, court, address, two prices, one button) stretched across the full viewport width.

**Solution:** Wrap the page content in `max-w-lg mx-auto` to center it in a narrower column.

**File:** `app/views/properties/show.html.erb`

**Change:** Add `max-w-lg mx-auto` to the root container `<div>`.

## 2. Sidebar — Active Menu Highlight on Subpages

**Problem:** The sidebar `active?` method uses exact path matching (`item.path == @current_path`). When the user navigates to `/properties/1/inspections/tabs/sale_document`, no sidebar item highlights because the path doesn't exactly match `/properties` (the "물건 목록" menu path).

**Solution:** Change the `active?` method in `Sidebar::Component` from exact matching to prefix matching using `start_with?`.

**File:** `app/components/sidebar/component.rb`

**Change:**
```ruby
# Before
def active?(item)
  item.path.present? && item.path == @current_path
end

# After
def active?(item)
  item.path.present? && @current_path.start_with?(item.path)
end
```

**Edge case:** The root path `/` would match everything. The sidebar currently has no root-path menu item, so this is not an issue. If one is added later, add an exact-match check for `/`.

## 3. Inspection Layout — Property Price Badges

**Problem:** The inspection layout header shows the user's 최대입찰가 (max bid amount, blue badge) but not the property's own prices — 감정가 (appraisal price) and 최저매각가 (minimum sale price). Users need these for context during analysis.

**Solution:** Add two amber-colored badges for 감정가 and 최저매각가 to the left of the existing blue 최대입찰가 badge.

**File:** `app/views/inspections/_layout.html.erb`

**Design:**
- Color: Amber (`bg-amber-50 dark:bg-amber-900/20 border-amber-200 dark:border-amber-800 text-amber-700 dark:text-amber-300`) — complementary to the existing blue badge
- Color semantics: amber = property price info, blue = user budget info
- Data source: `property.appraisal_price` and `property.min_bid_price` (the `property` local variable already available in the partial)
- Format: `format_price_in_eok()` helper (same as existing badge)
- Layout: flex row with gap, wraps on small screens

**Badge order (left to right):**
1. 감정가 (amber)
2. 최저매각가 (amber)
3. 최대입찰가 (blue, existing)

## Scope

- No database changes
- No new components or controllers
- No JavaScript changes
- Three files modified: `properties/show.html.erb`, `sidebar/component.rb`, `inspections/_layout.html.erb`
