# Court Auction Search: 100-Item Cap + 20-Per-Page Pagination

**Date:** 2026-04-20
**Status:** Design approved, pending implementation plan

## Context

Today the criteria search (`CourtAuctionSearchService`) fetches **every matching page** returned by the court auction API and stores all dedup-ed case numbers into `user.search_results`. `PropertiesController#index` then shows only the first 20 rows with an "최대 20건까지 조회됩니다" banner when more exist. The rest of the stored rows are effectively hidden until the user clears state.

We want two changes:

1. **Cap fetching at 100 items** (post-dedup) so API cost is bounded.
2. **Paginate display**: 20 items per page with numbered navigation (`‹ 1 2 3 4 5 ›`).

## Decisions (from brainstorming)

| # | Topic | Decision |
|---|---|---|
| 1 | Fetch strategy | **Eager** — fetch up to 100 upfront, paginate from DB. |
| 2 | Pagination UI | **Numbered pages + prev/next** (`‹ 1 2 3 4 5 ›`). |
| 3 | Meaning of "100" | **DB-store 100** (post-dedup); already-imported items are filtered at display time without back-filling. |
| 4 | Navigation mechanism | **Turbo Frame + GET** with `search_page=N` query param. |
| 5 | Import-in-page behavior | **Current behavior unchanged** — fade-out + count update only, no pagination recompute. |
| 6 | Over-100 messaging | **Banner** — "전체 M건 중 상위 100건만 조회됩니다". |

## Architecture

```
[검색 버튼] ──POST /search_results──> CourtAuctionSearchService
                                         │
                                         ├─ CriteriaSearchClient.search_all(max_items: 100)
                                         │     └─ 조기 종료: items ≥ 100 또는 totalCnt 도달
                                         │     └─ returns { items, total_count }
                                         │
                                         └─ persist_results
                                                ├─ user.update(last_search_api_total_count:)
                                                ├─ user.search_results.destroy_all
                                                └─ dedup 후 최대 100건 저장
                                         │
                                         ▼
                              redirect_to properties_path
                                         │
[GET /properties?search_page=N] ─> properties#index
                                         │
                                         ├─ 이미 import된 case_number 제외
                                         ├─ total_displayable = 쿼리.count
                                         ├─ total_pages = (total_displayable / 20.0).ceil
                                         ├─ @search_page = params[:search_page].to_i.clamp(1, [total_pages, 1].max)
                                         ├─ @search_results = 쿼리.offset((N-1)*20).limit(20)
                                         └─ @api_total_count = user.last_search_api_total_count
                                         │
                                         ▼
                           <turbo-frame id="search-results-frame">
                             ├─ 헤더: "조건검색 결과 N건" + (api_total_count > 100 배너)
                             ├─ 그리드 (카드 20개)
                             └─ _pagination.html.erb (‹ 1 2 3 4 5 ›)
```

## Components

### Changed

| File | Change |
|------|--------|
| `app/adapters/court_auction/criteria_search_client.rb` | `search_all` accepts `max_items:` (default 100). Early-exit loop when `all_items.size >= max_items`. Returns `{ items:, total_count: }` (total_count unchanged; reflects API's `totalCnt`). |
| `app/adapters/court_auction_adapter.rb` | Interface signature: `search_by_criteria(region_code:, max_price:, max_items:)`. |
| `app/adapters/government_court_auction_adapter.rb` | Forwards `max_items` to client. |
| `app/services/court_auction_search_service.rb` | Adds `MAX_ITEMS = 100`. Calls adapter with `max_items: MAX_ITEMS`. Updates `user.last_search_api_total_count` with `response[:total_count]`. `destroy_all` + dedup + create (up to 100). |
| `app/controllers/properties_controller.rb#index` | Adds pagination assigns: `@search_page`, `@total_pages`, `@search_results` (paginated), `@api_total_count`, `@over_api_limit`. Removes existing `@over_limit` / `limit(20)` logic. |
| `app/controllers/search_results_controller.rb#create` | Replaces the current turbo_stream response with a redirect to `properties_path` (no `search_page` param → defaults to page 1). The `html` response path (already a redirect) is kept. This aligns the criteria-search flow with the new Turbo Frame-based pagination, which reloads naturally on full navigation. |
| `app/views/properties/index.html.erb` | Wraps the existing `<div id="criteria-search-results">` contents with `<turbo-frame id="search-results-frame">`. |
| `app/views/search_results/_inline_results.html.erb` | Replaces `over_limit` banner with `api_total_count` banner ("전체 M건 중 상위 100건만 조회됩니다"). Renders grid + `_pagination` partial. Accepts `search_page`, `total_pages`, `api_total_count` locals. |

### New

| File | Purpose |
|------|---------|
| `app/views/search_results/_pagination.html.erb` | Renders `‹ 1 2 3 4 5 ›`. Hidden when `total_pages <= 1`. Links use `request.query_parameters.merge(search_page: N)` to preserve other filters (`safety_rating`, `search`, `within_budget`). |
| `db/migrate/<ts>_add_last_search_api_total_count_to_users.rb` | `add_column :users, :last_search_api_total_count, :integer` (nullable). |

### Unchanged

- `SearchResult` model & schema — dedup/property_count logic stays intact.
- `inline_import` turbo_stream flow (fade-out + count update).
- `RateLimiter`, `ResponseParser`, `BrowserClient`.
- Detail-search (case-number) flow on the same page.

## Data Flow & Storage

### Why store `api_total_count` on `users`

`search_results` rows are wiped on every new search (`destroy_all`). The API's `totalCnt` (used for the over-100 banner) must survive past persistence and be available across paginated GETs.

- **Chosen:** `users.last_search_api_total_count :integer` (nullable). Written once per search. Read once per `properties#index`.
- **Rejected:** denormalized column on `search_results` (100 duplicate writes; loses value when 0 results).
- **Rejected:** `Rails.cache` / session (transient; loses after cache expiry or cookie reset).

The choice also distinguishes two states that matter for UX:
- `last_search_api_total_count = 0` → "검색 조건에 맞는 물건이 없습니다"
- `last_search_api_total_count > 100` → over-100 banner

### Pagination math

Per request:

```ruby
existing = current_user.properties.pluck(:case_number)
scope = current_user.search_results.where.not(case_number: existing).order(created_at: :desc)
total_displayable = scope.count
total_pages = (total_displayable.to_f / 20).ceil
page = params[:search_page].to_i.clamp(1, [total_pages, 1].max)
@search_results = scope.offset((page - 1) * 20).limit(20)
```

## Edge Cases

| Situation | Handling |
|-----------|----------|
| `search_page` out of range (0, negative, > total_pages) | Clamped to `[1, total_pages]`. No redirect (URL manipulation allowed). |
| Search returns 0 items | Empty state message; pagination hidden. |
| `total_pages == 1` | Pagination hidden (no `‹ 1 ›` when only 1 page). |
| API total < 100 | No banner. Header shows `"조건검색 결과 N건"` only. |
| API total ≥ 100 (truncated) | Banner: `"전체 M건 중 상위 100건만 조회됩니다"`. |
| Import reduces `total_displayable` below `(page - 1) × 20` | Current page stays as-is per decision #5; next navigation click re-clamps. |
| Non-integer `search_page` (`?search_page=abc`) | `to_i` → 0 → clamped to 1. |
| `users.last_search_api_total_count` is nil (pre-migration user) | No banner. Normal operation. |
| Pagination click while no search executed | `total_pages = 0`, clamped to 1, empty state rendered. |

## Error Handling

| Situation | Handling |
|-----------|----------|
| Network error mid-fetch (e.g., page 5 `Faraday::TimeoutError`) | `CriteriaSearchClient#search` raises `DataProvider::ConnectionError`; `search_all` loop aborts; `Service` rescues and returns `Result.new(count: 0, error: e)`. **`destroy_all` has not run yet**, so existing results are preserved. |
| API response missing `totalCnt` | `.to_i` → 0 → no banner, normal operation. |
| Partial fetch (e.g., 40 items before failure) | Not persisted. All-or-nothing. |

## Testing Strategy (TDD)

### Unit: `CriteriaSearchClient#search_all`

- `totalCnt=50`, max_items=100 → 1 API call; returns 50 items.
- `totalCnt=150`, max_items=100 → exactly 10 API calls; returns 100 items; `total_count=150`.
- `totalCnt=95`, max_items=100 → 10 API calls; returns 95 items.
- `totalCnt=100`, max_items=100 → exactly 10 API calls.
- Fixtures: `court_auction_criteria_search_page1..page10.json`.

### Unit: `CourtAuctionSearchService#call`

- On success, `user.last_search_api_total_count` equals API's `totalCnt`.
- When `totalCnt > 100`, exactly 100 (or fewer post-dedup) rows created.
- Existing error-handling tests continue to pass.

### Controller: `PropertiesController#index`

- `search_page=1` → rows 1–20.
- `search_page=3` → rows 41–60.
- `search_page=99` with 3 pages → clamped to page 3.
- `search_page=abc` → page 1.
- `last_search_api_total_count=150` → banner rendered.
- `last_search_api_total_count=80` → banner hidden.
- Import flow: `total_displayable` header count decreases by 1.

### View/System

- Pagination links preserve `safety_rating`, `search`, `within_budget` query params.
- DOM: 5 numbered links + prev + next when `total_pages=5`.
- `total_pages=1` → pagination element absent.
- Turbo Frame request returns only the frame's content.

### TDD Order

1. RED: `CriteriaSearchClient#search_all` max_items early-exit test.
2. GREEN + REFACTOR.
3. Service layer: `last_search_api_total_count` update.
4. Controller: paginated assigns.
5. View + system: pagination rendering + frame navigation.

### Migration

- `AddLastSearchApiTotalCountToUsers` — single `add_column` on a nullable integer. Rollback-safe. No data backfill required (nil → no banner, which is acceptable for pre-existing sessions).

## Out of Scope

- Changes to case-number (detail) search flow.
- Changes to `RateLimiter` or `BrowserClient`.
- Sort/filter options on search results (current `order(created_at: :desc)` preserved).
- Increasing the 100-cap or making it user-configurable.
- Cross-session search history / retaining search results after logout.
