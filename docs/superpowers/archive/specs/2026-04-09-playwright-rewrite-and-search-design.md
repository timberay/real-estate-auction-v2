# Playwright Rewrite & Criteria Search Design

**Date:** 2026-04-09
**Status:** Approved

## Goal

1. Replace Ferrum with `playwright-ruby-client` for court auction browser automation
2. Add criteria-based search (region, usage, price range) that returns a list of properties
3. Save search parameters per user in `budget_settings`
4. Store search result lists in a new `search_results` table for user selection

## Architecture

```
[사건번호 검색]                    [조건 검색]
     │                                │
     ▼                                ▼
PropertiesController#create    SearchResultsController#create
     │                                │
     ▼                                ▼
PropertyDataSyncService        CourtAuctionSearchService
     │                                │
     ▼                                ▼
GovernmentCourtAuctionAdapter  GovernmentCourtAuctionAdapter
     │                                │
     ▼                                ▼
CourtAuction::BrowserClient (Playwright)
     │
     ▼
courtauction.go.kr (PGJ151F00.xml)
```

Both flows share the same BrowserClient, which provides two methods:
- `fetch_with_detail(year:, type:, number:)` — case number search → detail
- `search_by_criteria(region:, year:, min_price:, max_price:)` — criteria search → list

## Data Model Changes

### budget_settings: add region column

```ruby
add_column :budget_settings, :region, :string, default: "제주특별자치도"
```

Valid regions (constant):
```ruby
REGIONS = [
  "서울특별시", "부산광역시", "대구광역시", "인천광역시", "광주광역시",
  "대전광역시", "울산광역시", "세종특별자치시", "경기도", "강원도",
  "충청북도", "충청남도", "전라북도", "전라남도", "경상북도",
  "경상남도", "제주특별자치도", "강원특별자치도", "전북특별자치도"
].freeze
```

Default: "제주특별자치도" (when user has no setting).

### New table: search_results

Temporary list storing criteria search results per user.

```ruby
create_table :search_results do |t|
  t.references :user, null: false
  t.string :case_number, null: false
  t.string :court_name
  t.string :address
  t.integer :appraisal_price
  t.integer :min_bid_price
  t.string :property_type
  t.string :status
  t.integer :failed_bid_count
  t.string :auction_date
  t.string :remarks
  t.timestamps
end

add_index :search_results, [:user_id, :case_number], unique: true
```

Replace strategy: each search deletes all existing `search_results` for the user and inserts fresh results.

### API → search_results field mapping

| API field | Column |
|-----------|--------|
| `srnSaNo` | `case_number` |
| `jiwonNm` | `court_name` |
| `printSt` | `address` |
| `gamevalAmt` | `appraisal_price` |
| `minmaePrice` | `min_bid_price` |
| `dspslUsgNm` | `property_type` |
| `mulJinYn` | `status` (Y=진행중, else 종결) |
| `yuchalCnt` | `failed_bid_count` |
| `maeGiil` | `auction_date` |
| `mulBigo` | `remarks` |

## Search Parameters

### Criteria search parameters (for `search_by_criteria`)

| Parameter | Source | Court auction form element |
|-----------|--------|---------------------------|
| Region | `budget_settings.region` (default: "제주특별자치도") | 소재지(새주소) → 시/도 select (DOM `dispatchEvent`) |
| Year | `Time.current.year` | 사건연도 select |
| Bid type | Fixed: "전체" | 입찰구분 (no change needed, default) |
| Usage | Fixed: "건물" → "주거용건물" | 대분류 → 중분류 (DOM `dispatchEvent` for cascade) |
| Min price | Fixed: "5천만원" | 최저매각가격 하한 |
| Max price | Derived from `budget_settings.max_bid_amount` | 최저매각가격 상한 |

### Max price conversion logic

Court auction site options: 1천만원, 5천만원, 1억원, 1억5천만원, 2억원, ..., 9억5천만원, 10억원

```ruby
# max_bid_amount is in 만원 units
# Find the first option value (in won) that is >= max_bid_amount * 10000
# Default: 5억원 (500000000) when max_bid_amount is nil
PRICE_OPTIONS = [
  10_000_000, 50_000_000, 100_000_000, 150_000_000,
  200_000_000, 250_000_000, 300_000_000, 350_000_000,
  400_000_000, 450_000_000, 500_000_000, 550_000_000,
  600_000_000, 650_000_000, 700_000_000, 750_000_000,
  800_000_000, 850_000_000, 900_000_000, 950_000_000,
  1_000_000_000
].freeze

def max_price_option(max_bid_amount)
  return 500_000_000 unless max_bid_amount
  target = max_bid_amount * 10_000
  PRICE_OPTIONS.find { |v| v >= target } || PRICE_OPTIONS.last
end
```

### Case number search parameters (for `fetch_with_detail`)

Only year and case number fields are filled. All other form fields remain untouched (default values).

## BrowserClient (Playwright)

### Dependency change

```ruby
# Gemfile
gem "playwright-ruby-client"  # ADD
# gem "ferrum"                # REMOVE
```

Requires: `npx playwright install chromium`

### Playwright interaction patterns (verified via MCP test)

| Element | Method |
|---------|--------|
| Select (dropdown) | DOM `el.value = x` + `el.dispatchEvent(new Event('change', {bubbles: true}))` |
| Input (text) | `page.fill('#selector', 'value')` or `page.type('#selector', 'value')` |
| Radio button | `element.click()` |
| Search button | `page.evaluate("WebSquare...trigger('onclick')")` |
| API response capture | `page.expect_response(url_pattern)` or route intercept |
| Cascading selects | Set parent via DOM dispatchEvent, wait, then set child |

### Key element IDs

| Purpose | Element ID |
|---------|-----------|
| Court select | `mf_wfm_mainFrame_sbx_rletCortOfc` |
| Region radio (새주소) | `mf_wfm_mainFrame_rad_rletSrchBtn_input_2` |
| Region 시/도 select | `mf_wfm_mainFrame_sbx_rletAdongSdR` |
| Year select | `mf_wfm_mainFrame_sbx_rletCsYear` |
| Case number input | `mf_wfm_mainFrame_ibx_rletCsNo` |
| Usage large select | `mf_wfm_mainFrame_sbx_rletLclLst` |
| Usage mid select | `mf_wfm_mainFrame_sbx_rletMclLst` |
| Min price select | `mf_wfm_mainFrame_sbx_rletLwsDspslMin` |
| Max price select | `mf_wfm_mainFrame_sbx_rletLwsDspslMax` |
| Search button | `mf_wfm_mainFrame_btn_gdsDtlSrch` |

### Search API endpoint

`POST /pgj/pgjsearch/searchControllerMain.on`

### Detail API endpoint

`POST /pgj/pgj15B/selectAuctnCsSrchRslt.on`

## Service Layer

### PropertyDataSyncService (existing — minimal change)

No API change. BrowserClient internals change from Ferrum to Playwright, but the service interface stays the same:

```ruby
PropertyDataSyncService.call(case_number: "2024타경6008")
```

### CourtAuctionSearchService (new)

```ruby
CourtAuctionSearchService.call(user: current_user)
# 1. Read region, max_bid_amount from user.budget_setting
# 2. Convert max_bid_amount → court auction price option
# 3. Call BrowserClient#search_by_criteria
# 4. Delete user's existing search_results, insert new ones
# => { count: 14, results: [...] }
```

## Controller Layer

### SearchResultsController (new)

```ruby
POST /search_results           # Run criteria search, save results
GET  /search_results           # Display saved search results list
POST /search_results/:id/import  # Import selected item → PropertyDataSyncService
```

`import` action reuses `PropertyDataSyncService.call(case_number:)` to fetch detail and store as Property.

### Error handling

Same pattern as `PropertiesController#error_message_for` — map DataProvider errors to Korean user messages.

## Test Strategy

| Layer | Method |
|-------|--------|
| BrowserClient | Mock Playwright page/response objects |
| CourtAuctionSearchService | Stub BrowserClient, verify search_results DB |
| SearchResultsController | Integration tests (search/list/import scenarios) |
| PropertyDataSyncService | Existing tests (already passing) |
| Price option conversion | Unit test for max_bid_amount → option mapping |
| Region validation | Unit test for budget_settings.region |
| Live site testing | Manual only — `bin/rails runner` verification |
