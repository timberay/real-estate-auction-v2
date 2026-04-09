# Criteria Search UX Improvements

**Date:** 2026-04-09
**Status:** Approved

## Overview

Improve the criteria search results UX on the properties index page (물건 목록). Changes span layout, animations, loading state, server-side filtering, and result limits.

## Requirements

| # | Requirement | Summary |
|---|------------|---------|
| 1 | Remove close button | The "✕ 닫기" button in the results header is unnecessary |
| 2 | Multi-column grid | Results display in responsive 4/3/2/1 columns matching property cards |
| 3 | Fade out on add | Added item fades out and is removed from search results |
| 4 | Fade in on add | Added item appears in property list with fade-in animation |
| 5 | Loading state | Replace blur overlay with pointer-events-none + cursor-wait |
| 6 | Reset on search | New search replaces previous results entirely |
| 7 | Exclude existing | Already-added properties are excluded from search results server-side |
| 8 | Max 20 results | Limit to 20 results; show message when limit is reached |

## Approach

Turbo Stream-centric: extend existing Hotwire architecture with CSS transitions and minimal Stimulus additions.

## Design

### 1. Layout — Results Box Repositioning

**Current:** `#criteria-search-results` is inside `div[data-controller="criteria-search"]` which has `max-w-md`.

**New:** Move `#criteria-search-results` outside the `max-w-md` container so it spans full page width.

```
┌─ max-w-md ──────────────────────┐
│ [관심 지역]                      │
│ [사건번호 입력] [+] [조건검색]    │
└─────────────────────────────────┘

┌─ full-width ────────────────────────────────────────┐
│ 조건검색 결과 5건  ("최대 20건까지 조회됩니다" 조건부) │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐        │
│ │ 카드 1  │ │ 카드 2  │ │ 카드 3  │ │ 카드 4  │  ← lg │
│ └────────┘ └────────┘ └────────┘ └────────┘        │
└────────────────────────────────────────────────────┘

┌─ full-width ────────────────────────────────────────┐
│ [필터/검색바]                                        │
│ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐        │
│ │물건카드 │ │물건카드 │ │물건카드 │ │물건카드 │        │
│ └────────┘ └────────┘ └────────┘ └────────┘        │
└────────────────────────────────────────────────────┘
```

- Results grid class: `grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4` (same as property cards)
- Remove the close button ("✕ 닫기") from the header
- Remove pagination (all results shown at once, max 20)

### 2. Loading State

**Current:** Semi-transparent `backdrop-blur-sm` overlay with "처리 중..." text covers the entire criteria-search area.

**New:**
- Remove `showOverlay()` / `hideOverlay()` methods from criteria_search_controller.js
- During search, apply `pointer-events-none` and `cursor-wait` to the criteria-search controller element
- Keep existing behavior: button spinner, input/button disabled states, `opacity-50` on disabled buttons
- Remove on `turbo:submit-end` (same as current enable flow)

### 3. Fade Out / Fade In Animation

When a user clicks a search result item to add it:

**Turbo Stream response from `inline_import` returns 3 operations:**

1. **Replace search item** with a fade-out wrapper:
   - Replace the item div with a wrapper that has `data-controller="fade-remove"`
   - On `connect()`, the Stimulus controller triggers opacity → 0, max-height → 0 (300ms CSS transition)
   - After transition ends, remove the element from DOM

2. **Append to property cards grid** (`#property-cards-grid`):
   - Append a new `PropertyCardComponent` wrapped with initial `opacity-0`
   - CSS transition fades it in to `opacity-1` over 300ms
   - Uses a small Stimulus controller (`fade-in`) that adds `opacity-100` class on `connect()`

3. **Update results count header:**
   - Turbo Stream updates the count span in the results header
   - If count reaches 0, replace the count update with `turbo_stream.update("criteria-search-results", "")` to clear the entire results box

**New Stimulus controllers:**
- `fade-remove`: On connect → apply transition classes → on `transitionend` → `this.element.remove()`
- `fade-in`: On connect → next frame → add `opacity-100` class (transition from `opacity-0`)

### 4. Server-Side Changes

#### Exclude existing properties (Requirement 7)

In `SearchResultsController#create`, after calling the search service:

```ruby
existing_case_numbers = current_user.properties.pluck(:case_number)
search_results = current_user.search_results.where.not(case_number: existing_case_numbers)
```

#### Max 20 results (Requirement 8)

```ruby
total_count = search_results.count
search_results = search_results.limit(20)
over_limit = total_count > 20
```

Pass `over_limit` to the partial. When true, display: "최대 20건까지 조회됩니다" in the results header.

#### Reset on search (Requirement 6)

Already handled: `CourtAuctionSearchService.call` replaces existing search results, and Turbo Stream `update` replaces the container content entirely.

#### Remove pagination

- Remove `inline_page` action from `SearchResultsController`
- Remove `inline_page` route from `config/routes.rb`
- Remove Pagy from `PropertiesController#index` (search results portion)
- Delete `_inline_results_page.html.erb` partial
- Remove Pagy gem from Gemfile (only used here)
- Delete `config/initializers/pagy.rb`

### 5. Inline Import Response Changes

Current `inline_import` replaces the item with "✓ 추가됨" state.

New `inline_import` response (Turbo Stream, 3 operations):

```ruby
respond_to do |format|
  format.turbo_stream do
    render turbo_stream: [
      # 1. Replace search item with fade-out wrapper
      turbo_stream.replace(dom_id(search_result, :inline), partial: "search_results/inline_result_fade_out", locals: { search_result: search_result }),
      # 2. Append property card to grid
      turbo_stream.append("property-cards-grid", partial: "search_results/inline_imported_card", locals: { property: @property, user_property: @user_property }),
      # 3. Update results count
      turbo_stream.update("criteria-search-count", html: "#{remaining_count}건")
    ]
  end
end
```

### 6. Removed Item State

The "✓ 추가됨" (already added) state in `_inline_result_item.html.erb` is no longer needed:
- Items already added are excluded from search results (requirement 7)
- Items added during the session fade out and are removed (requirement 3)

Remove the `already_added` conditional branch from the partial.

## Files Changed

| File | Change |
|------|--------|
| `app/views/properties/index.html.erb` | Move `#criteria-search-results` outside `max-w-md`, add `id="property-cards-grid"` to cards grid |
| `app/views/search_results/_inline_results.html.erb` | Remove close button, remove pagination, grid layout, over_limit message, count span with ID |
| `app/views/search_results/_inline_result_item.html.erb` | Remove `already_added` state branch |
| `app/controllers/search_results_controller.rb` | Exclude existing properties, limit 20, remove `inline_page` action, update `inline_import` to return 3 Turbo Streams |
| `app/controllers/properties_controller.rb` | Remove Pagy for search results |
| `app/javascript/controllers/criteria_search_controller.js` | Replace overlay with pointer-events-none/cursor-wait |
| `app/javascript/controllers/fade_remove_controller.js` | **New** — fade-out + DOM removal |
| `app/javascript/controllers/fade_in_controller.js` | **New** — fade-in on connect |
| `app/views/search_results/_inline_result_fade_out.html.erb` | **New** — fade-out wrapper partial |
| `app/views/search_results/_inline_imported_card.html.erb` | **New** — fade-in wrapper for PropertyCardComponent |
| `config/routes.rb` | Remove `inline_page` route |
| `test/controllers/search_results_controller_inline_test.rb` | Update tests for new behavior |

## Files Deleted

| File | Reason |
|------|--------|
| `app/views/search_results/_inline_results_page.html.erb` | Pagination removed |
| `config/initializers/pagy.rb` | Pagy gem removed |

## Gems

- Remove `pagy` from Gemfile (only used for search results pagination)
