# CourtAuction Scraper Redesign: Faraday → Playwright (Ferrum)

> **Date:** 2026-04-09
> **Status:** Approved
> **Supersedes:** `2026-04-09-court-auction-scraper-design.md` (Faraday-based, invalidated by WAF)
> **References:** `2026-04-09-court-auction-api-field-analysis.md`, `2026-04-09-data-provider-architecture-design.md`

## Background

Live testing revealed that courtauction.go.kr deploys a WAF (Web Application Firewall) that blocks all direct HTTP requests (curl, Faraday, etc.). Only browser-based requests succeed. The existing Faraday-based implementation must be replaced with browser automation.

### Key Findings

| Method | Result |
|--------|--------|
| curl / Faraday (direct HTTP) | **BLOCKED** — WAF returns "Web firewall security policies have been blocked" |
| Playwright browser (route interception) | **WORKS** — Full API response received |

## Architecture Decision

**Approach: Route Interception via Ferrum (CDP)**

The browser navigates to the court auction search page, fills the search form, and submits. Meanwhile, a network listener intercepts the XHR response from the API endpoint and captures the JSON directly. No HTML DOM parsing required.

**Why Ferrum over alternatives:**
- Pure Ruby CDP client — no Node.js dependency (consistent with ImportMap-based, Node-free project)
- Lighter than Selenium/Capybara for server-side scraping
- Direct Chrome DevTools Protocol access for network interception

**Why Route Interception over DOM scraping:**
- JSON response is structured, stable data (API contract)
- HTML layout changes don't break the scraper
- Already validated during API field analysis

## File Changes

### Delete (Faraday-based — WAF blocked)

| File | Reason |
|------|--------|
| `app/adapters/court_auction/base_client.rb` | Faraday HTTP client config |
| `app/adapters/court_auction/search_client.rb` | Faraday search API call |
| `app/adapters/court_auction/detail_client.rb` | Faraday detail API call |
| `test/adapters/court_auction/search_client_test.rb` | Faraday stub test |
| `test/adapters/court_auction/detail_client_test.rb` | Faraday stub test |
| `test/adapters/government_court_auction_adapter_integration_test.rb` | Faraday stub integration test |
| `test/fixtures/files/court_auction_search_response.json` | Wrong field names |
| `test/fixtures/files/court_auction_detail_response.json` | Wrong field names |

### Create

| File | Role |
|------|------|
| `app/adapters/court_auction/browser_client.rb` | Ferrum browser control + route interception |
| `test/adapters/court_auction/browser_client_test.rb` | BrowserClient unit test (stubbed) |
| `test/fixtures/files/court_auction_search_intercepted.json` | Real captured API response fixture |
| `test/adapters/government_court_auction_adapter_integration_test.rb` | Rewritten integration test |

### Modify

| File | Change |
|------|--------|
| `app/adapters/government_court_auction_adapter.rb` | Replace SearchClient/DetailClient with BrowserClient |
| `app/adapters/court_auction/response_parser.rb` | Fix all field name mappings |
| `test/adapters/court_auction/response_parser_test.rb` | Update for new fixture |
| `Gemfile` | Add `ferrum`, remove `faraday`/`faraday-retry` |

### Keep (no changes)

| File | Reason |
|------|--------|
| `app/adapters/court_auction/case_number_parser.rb` | WAF-independent, logic valid |
| `app/adapters/court_auction/rate_limiter.rb` | Still needed for browser requests |
| `app/adapters/court_auction_adapter.rb` | Factory pattern unchanged |
| `app/adapters/mock_court_auction_adapter.rb` | Test mock unchanged |
| `test/fixtures/files/court_auction_empty_search.json` | Empty result fixture still valid |

## BrowserClient Design

### Flow

```
BrowserClient#fetch(case_number_params)
  │
  ├─ 1. Ferrum::Browser.new(headless: true)
  │
  ├─ 2. Register network listener
  │     └─ Intercept: POST "/pgj/pgjsearch/searchControllerMain.on"
  │        → Capture response body (JSON)
  │
  ├─ 3. page.go_to(search page URL)
  │
  ├─ 4. Fill search form via JavaScript evaluate
  │     └─ Set case year, type (타경), number → trigger search
  │
  ├─ 5. Wait for intercepted response (timeout: 30s)
  │
  ├─ 6. Parse JSON → return result hash
  │
  └─ 7. browser.quit (in ensure block)
```

### Error Handling

| Situation | Error |
|-----------|-------|
| Site unreachable | `DataProvider::ServiceUnavailableError` |
| No search results | Return `nil` |
| Timeout (30s) | `DataProvider::TimeoutError` |
| Chromium not installed | `DataProvider::ConfigurationError` |
| WAF block (unlikely with browser) | `DataProvider::ServiceUnavailableError` |

### Browser Lifecycle

- **MVP strategy:** Launch and quit browser per job execution
- Browser startup overhead: ~2-3 seconds (acceptable for background job)
- `ensure` block guarantees cleanup even on exceptions
- No persistent browser pool (avoid memory leak complexity)

## ResponseParser Field Mapping

### DB Column Mapping (6 fields)

| API Field (actual) | Old Spec (wrong) | DB Column |
|-------------------|-----------------|-----------|
| `srnSaNo` | ~~csNo~~ | `properties.case_number` |
| `jiwonNm` | ~~cortOfcNm~~ | `properties.court_name` |
| `dspslUsgNm` | ~~gdsMdlClsNm~~ | `properties.property_type` |
| `printSt` | ~~gdsDtlAdr~~ | `properties.address` |
| `gamevalAmt` | ~~aprsAmt~~ | `properties.appraisal_price` |
| `minmaePrice` | ~~lwstSaleAmt~~ | `properties.min_bid_price` |

### raw_data JSON Mapping (5 fields)

| API Field | Storage Path | Usage |
|-----------|-------------|-------|
| `mulBigo` | `raw_data.court_auction.remarks` | Rights detection (유치권/법정지상권) |
| `yuchalCnt` | `raw_data.court_auction.failed_bid_count` | Failed bid count |
| `mokGbncd` | `raw_data.court_auction.is_partial_share` | Partial share detection |
| `spJogCd` | `raw_data.court_auction.special_conditions` | Special conditions |
| `inqCnt` | `raw_data.court_auction.view_count` | View count (competition indicator) |

### Response Wrapper Change

```ruby
# Old (wrong)
response["dlt_list"]

# Actual
response.dig("data", "dlt_srchResult")

# Total count
response.dig("data", "dma_pageInfo", "totalCnt")
```

## Gem Changes

| Action | Gem | Reason |
|--------|-----|--------|
| **Add** | `ferrum` | Ruby CDP client for Chromium control |
| **Remove** | `faraday` | Only used by CourtAuction (being deleted) |
| **Remove** | `faraday-retry` | Faraday dependency (being deleted) |

## Docker / Infrastructure

### Dockerfile

Chromium must be installed in the production Docker image:

```dockerfile
RUN apt-get update && apt-get install -y chromium
```

- Image size increase: ~200-300MB
- Development: uses local Chrome/Chromium

### Environment Variables (optional)

| Variable | Default | Purpose |
|----------|---------|---------|
| `BROWSER_PATH` | System default | Custom Chromium binary path |
| `BROWSER_TIMEOUT` | `30` | Browser timeout in seconds |

## Test Strategy

### Unit Tests (no browser)

- **ResponseParser**: Feed captured JSON fixture → verify normalized output
- **CaseNumberParser**: Existing tests unchanged
- **RateLimiter**: Existing tests unchanged

### Integration Tests (stubbed browser)

- **BrowserClient**: Stub Ferrum to return fixture JSON, verify flow
- **GovernmentCourtAuctionAdapter**: Stub BrowserClient, verify end-to-end data flow

### Manual/E2E Tests

- Live browser test against courtauction.go.kr (not in CI)
- Validates WAF bypass still works

## Scope

### In scope (MVP)
- Search API only (listing results)
- Single case number lookup
- Background job execution (Solid Queue)

### Out of scope (future)
- Detail API (individual property deep info)
- Bulk search / pagination
- Browser pool for concurrent requests
- Captcha handling (not currently present)

## Obsoleted Documents

The following documents are superseded by this spec:
- `docs/superpowers/specs/2026-04-09-court-auction-scraper-design.md` — Faraday-based design (invalidated)
- `docs/superpowers/plans/2026-04-09-court-auction-scraper.md` — Faraday-based implementation plan (invalidated)
