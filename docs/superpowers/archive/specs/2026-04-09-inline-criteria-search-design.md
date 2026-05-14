# Inline Criteria Search on Properties Index

## Overview

Integrate criteria-based court auction search directly into the properties index page (`properties#index`), allowing users to discover auction listings based on their saved `BudgetSetting` (region, max bid price) without leaving the page.

Currently, criteria search lives on a separate `/search_results` page. This design moves the trigger into the properties index and displays results inline, reducing navigation friction.

## UI Design

### Button Placement

- A purple (#7c3aed) "조건검색" button is placed next to the existing blue "+" button
- `min-width: 100px`, `padding: 0 20px` to accommodate future i18n (English text)
- The total width of the input group (input + "+" + "조건검색") must not exceed the width of the filter/search bar below it

### Results Box

- Appears directly below the case number input group, above the filter/search bar
- Container: `bg-slate-800`, `border border-slate-700`, `rounded-xl`, `p-3.5`
- Header row: "조건검색 결과 N건" (left) + "✕ 닫기" button (right)
- Each result item is a card showing:
  - **Case number** (purple, bold) — top left
  - **Appraisal price** (감정가) — top right
  - **Min bid price** (최저매각가) — middle
  - **Address** (📍 prefix, truncated with ellipsis) — bottom

### States

| State | Button | Results Box |
|-------|--------|-------------|
| Default | "조건검색" (purple, enabled) | Hidden |
| Loading | "⟳ 검색중..." (disabled, dimmed) | Hidden, input area disabled |
| Results shown | "조건검색" (enabled, can re-search) | Visible with items |
| Empty results | "조건검색" (enabled) | Box with "검색 결과가 없습니다" message |
| Error | "조건검색" (enabled) | Flash error message (existing pattern) |

### Item Interaction

- **Clickable items**: hover border changes to purple (#7c3aed)
- **On click**: triggers the same flow as manually entering a case number — calls `PropertiesController#create` with the case number, which runs `PropertyDataSyncService` to fetch detail data and register the property
- **After successful registration**: item changes to "✓ 추가됨" state — green border (#166534), green text for case number, opacity 0.55, click disabled
- **Already registered items**: on initial load, cross-reference with user's existing properties and show them as "✓ 추가됨" immediately

## Technical Design

### Backend

**Reuse existing infrastructure** — no new services or adapters needed:

1. **`CourtAuctionSearchService.call(user:)`** — already implemented, searches by `BudgetSetting` criteria
2. **`SearchResult` model** — already persists criteria search results per user
3. **`PropertiesController#create`** — already handles case number → detail sync → property registration

**New controller action**: `PropertiesController#criteria_search` (or reuse `SearchResultsController#create` via Turbo)

- POST request triggers `CourtAuctionSearchService.call(user:)`
- Returns a Turbo Frame or Turbo Stream with the results list
- Results are rendered inline in the properties index page

### Frontend

**Turbo Frame approach**:
- Wrap the results box area in a `<turbo-frame id="criteria-search-results">`
- "조건검색" button submits a form (POST) targeting this frame
- Results are rendered server-side and streamed into the frame

**Stimulus controller** (`criteria_search_controller`):
- Manages loading state (disable inputs, show spinner on button)
- Handles item click → POST to `PropertiesController#create` with case number
- On successful property creation, updates the clicked item to "✓ 추가됨" state via Turbo Stream

### Data Flow

```
[조건검색 click]
    → POST /search_results (Turbo Frame)
    → CourtAuctionSearchService.call(user:)
    → GovernmentCourtAuctionAdapter.search_by_criteria(region, year, min_price, max_price)
    → Persist SearchResult records
    → Render results in turbo-frame#criteria-search-results

[Result item click]
    → POST /properties (with case_number param, Turbo Stream)
    → PropertyDataSyncService.call(case_number)
    → Property created + UserProperty linked
    → Turbo Stream replaces item with "✓ 추가됨" state
```

### Cross-referencing Existing Properties

When rendering search results, check each `SearchResult.case_number` against the user's existing `properties.pluck(:case_number)` to pre-mark already-registered items.

### Error Handling

Follow existing patterns:
- `DataProvider::TimeoutError` → flash alert "데이터 수집 시간이 초과되었습니다"
- `DataProvider::ServiceUnavailableError` → flash alert "법원경매 사이트에 접속할 수 없습니다"
- `DataProvider::ConfigurationError` → flash alert "브라우저 실행에 실패했습니다"
- Individual item registration errors → Turbo Stream with error message on the specific item

### Route

```ruby
# Reuse existing route:
resources :search_results, only: [ :index, :create ]

# Or add to properties:
resources :properties, only: [ :index, :show, :create ] do
  collection do
    post :criteria_search
  end
end
```

Preferred: reuse `SearchResultsController#create` and render results in a Turbo Frame, keeping the existing separation of concerns.

## Scope

### In Scope
- "조건검색" button on properties index
- Inline results box with case number / appraisal price / min bid price / address
- Click-to-register with "✓ 추가됨" feedback
- Loading and error states
- Cross-reference with existing user properties

### Out of Scope
- Criteria editing UI (uses saved BudgetSetting as-is)
- Pagination of search results (1st page only, as specified)
- Modifying the existing `/search_results` page (can be deprecated later)
