# CourtAuction Scraper — courtauction.go.kr Integration

> **Scope**: HTTP-based scraper for courtauction.go.kr using direct JSON POST calls via Faraday. No Playwright/browser dependency.
> **Parent spec**: [Data Provider Architecture](2026-04-09-data-provider-architecture-design.md)

## Context

courtauction.go.kr was rebuilt in ~2022 using WebSquare (a Korean enterprise JS UI framework). While the frontend requires JavaScript rendering, the underlying data APIs are JSON POST endpoints that can be called directly with an HTTP client. This eliminates the need for a headless browser.

The site has no robots.txt, no CAPTCHA, and no login requirement for public auction data.

### Related Specs

- [Data Provider Architecture](2026-04-09-data-provider-architecture-design.md) — Common infrastructure (CredentialResolver, error hierarchy, settings UI)
- [F02 Safe Property Filtering](2026-04-05-f02-safe-property-filtering-design.md) — Consumer of court auction data for auto-detection rules

---

## Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Scraping method | Direct HTTP POST to JSON endpoints | No browser needed; faster, lighter, Faraday already available |
| Data scope | Search + detail API (structured JSON) | PDF parsing deferred to Phase 2 |
| Search method | Case number direct lookup only | Matches current UX; condition search is a separate feature |
| Rate limiting | 0.5s between requests, max 60/min | Normal user browsing level; safe for government site |
| Consent | Required via Settings UI toggle | Inherited from parent spec; consent-only provider |

---

## 1. Architecture

### File Structure

```
app/adapters/
  court_auction_adapter.rb                 # Base adapter (existing, unchanged)
  government_court_auction_adapter.rb      # Main adapter — orchestrates search + detail
  mock_court_auction_adapter.rb            # Mock adapter (existing, unchanged)
  court_auction/
    search_client.rb                       # Calls search API endpoint
    detail_client.rb                       # Calls detail API endpoint
    response_parser.rb                     # Normalizes API responses to standard hash
    rate_limiter.rb                        # Request throttling
```

### Data Flow

```
User enters case_number ("2026타경10001")
  → PropertyDataSyncService
    → CredentialResolver (checks consent)
    → GovernmentCourtAuctionAdapter.fetch_data(case_number:)
      → CaseNumberParser.parse("2026타경10001")
        → { year: "2026", type: "타경", number: "10001" }
      → RateLimiter.throttle
      → SearchClient.search(year:, type:, number:)
        → POST /pgj/pgjsearch/searchControllerMain.on
        → Returns: list of matching cases with court codes
      → RateLimiter.throttle
      → DetailClient.fetch(court_code:, case_number:, item_number:)
        → POST /pgj/pgj15B/selectAuctnCsSrchRslt.on
        → Returns: full case detail (tenants, rights, etc.)
      → ResponseParser.parse(search_result, detail_result)
        → Returns: normalized hash (same shape as MockCourtAuctionAdapter)
  → Property.raw_data = { court_auction: result }
```

---

## 2. API Endpoints

### Search API

```
URL:    https://www.courtauction.go.kr/pgj/pgjsearch/searchControllerMain.on
Method: POST
Headers:
  Content-Type: application/json
  Accept: application/json
  User-Agent: Mozilla/5.0 (compatible)
  Referer: https://www.courtauction.go.kr/pgj/index.on
```

**Request body:**
```json
{
  "cortAuctnSrchCondCd": "0004601",
  "csNo": "10001",
  "csYr": "2026",
  "csCdNm": "타경",
  "pageNo": 1,
  "page": 10,
  "totalCnt": 0
}
```

**Response:** JSON with `dlt_list` array containing matching cases. Each entry includes `cortOfcCd` (court code), `csNo`, `csDtlNo` (item sequence), basic property info.

### Detail API

```
URL:    https://www.courtauction.go.kr/pgj/pgj15B/selectAuctnCsSrchRslt.on
Method: POST
Headers: (same as search)
```

**Request body:**
```json
{
  "cortOfcCd": "B001001",
  "csNo": "10001",
  "csYr": "2026",
  "csCdNm": "타경",
  "csDtlNo": "001"
}
```

**Response:** JSON with detailed case information including tenants, non-extinguished rights, remarks, sale schedule.

---

## 3. Case Number Parsing

Korean court case numbers follow the pattern: `{year}{type}{number}`

```ruby
module CourtAuction
  class CaseNumberParser
    PATTERN = /\A(\d{4})(타경|타채)(\d+)\z/

    def self.parse(case_number)
      normalized = DataProvider.normalize_case_number(case_number)
      match = PATTERN.match(normalized)
      raise DataProvider::ParseError, "Invalid case number format: #{case_number}" unless match

      {
        year: match[1],
        type: match[2],
        number: match[3]
      }
    end
  end
end
```

---

## 4. Response Parser — Data Mapping

The parser normalizes API responses to match the MockCourtAuctionAdapter return schema exactly.

### Output schema (same as mock):

```ruby
{
  case_number: String,          # "2026타경10001"
  court_name: String,           # "서울중앙지방법원"
  property_type: String,        # "아파트", "빌라", "오피스텔"
  address: String,              # Full address
  appraisal_price: Integer,     # In won (정수, 원 단위)
  min_bid_price: Integer,       # In won
  remarks: String,              # 비고사항
  non_extinguished_rights: Array,  # ["전세권", "지상권"]
  tenants: Array,               # [{name:, deposit:, move_in_date:, dividend_requested:}]
  separate_land_registry: Boolean,
  lien_reported: Boolean,
  use_approval: Boolean,
  wall_partition_issue: Boolean,
  is_partial_share: Boolean,
  # New fields (not in mock, additive):
  failed_bid_count: Integer,    # 유찰횟수
  sale_schedule: Array,         # [{date:, min_price:, result:}]
  status: String                # "진행", "매각", "취하"
}
```

### Field mapping from API response:

| Output field | API source | Mapping logic |
|-------------|-----------|---------------|
| `case_number` | search: `csYr` + `csCdNm` + `csNo` | Concatenate |
| `court_name` | search: `cortOfcNm` | Direct |
| `property_type` | search: `gdsMdlClsNm` | Map to standard names |
| `address` | search: `gdsDtlAdr` | Direct |
| `appraisal_price` | search: `aprsAmt` | Integer conversion |
| `min_bid_price` | search: `lwstSaleAmt` | Integer conversion |
| `remarks` | detail: `bkgsRmk` | Direct |
| `non_extinguished_rights` | detail: `dlt_neRghts` | Extract array |
| `tenants` | detail: `dlt_tenants` | Map fields |
| `separate_land_registry` | detail: `sprtLandRgstYn` | "Y" → true |
| `lien_reported` | detail: `lienRptYn` | "Y" → true |
| `use_approval` | detail: `useAprYn` | "Y" → true |
| `is_partial_share` | search: `gdsStndCd` | Check share flag |
| `failed_bid_count` | search: `flbdCnt` | Integer conversion |

### Required fields validation:

```ruby
REQUIRED_FIELDS = %i[case_number court_name address appraisal_price min_bid_price].freeze
```

If any required field is blank after parsing, raise `DataProvider::ParseError`.

---

## 5. Rate Limiter

```ruby
module CourtAuction
  class RateLimiter
    MIN_INTERVAL = 0.5    # seconds between requests
    MAX_PER_MINUTE = 60

    def initialize
      @last_request_at = nil
      @request_times = []
    end

    def throttle
      wait_for_interval
      check_per_minute_limit
      record_request
    end

    private

    def wait_for_interval
      return unless @last_request_at
      elapsed = Time.current - @last_request_at
      sleep(MIN_INTERVAL - elapsed) if elapsed < MIN_INTERVAL
    end

    def check_per_minute_limit
      cutoff = Time.current - 60
      @request_times.reject! { |t| t < cutoff }
      if @request_times.size >= MAX_PER_MINUTE
        raise DataProvider::RateLimitError, "Court auction rate limit: #{MAX_PER_MINUTE}/min exceeded"
      end
    end

    def record_request
      @last_request_at = Time.current
      @request_times << Time.current
    end
  end
end
```

The rate limiter is instance-level (per adapter instance). Since `PropertyDataSyncService` creates a new adapter per call, rate limiting across users requires a class-level or shared state — for MVP, instance-level is sufficient since a single user won't exceed 60 req/min.

---

## 6. Error Handling

All errors follow the DataProvider error hierarchy from the parent spec.

| Scenario | Error class | Detection |
|----------|------------|-----------|
| Case number not found | `DataNotFoundError` | HTTP 200 + empty `dlt_list` |
| API returns error in body | `ParseError` | HTTP 200 + `resultCode != "00"` |
| IP blocked / 403 | `IpBlockedError` | HTTP 403 or known block response pattern |
| Server error | `ServiceUnavailableError` | HTTP 5xx (auto-retry 2x via faraday-retry) |
| Network failure | `ConnectionError` | Faraday::ConnectionFailed / TimeoutError |
| Missing required fields | `ParseError` | Required fields validation after parsing |
| Unknown response structure | `SiteStructureChangedError` | Expected JSON keys missing from response |
| Rate limit exceeded | `RateLimitError` | Internal rate limiter threshold |

### Site structure change detection:

```ruby
EXPECTED_SEARCH_KEYS = %w[dlt_list totalCnt].freeze
EXPECTED_DETAIL_KEYS = %w[cortOfcNm csNo].freeze

def validate_structure!(response, expected_keys)
  missing = expected_keys - response.keys
  if missing.any?
    raise DataProvider::SiteStructureChangedError,
      "Missing expected keys: #{missing.join(', ')}. Site may have changed."
  end
end
```

---

## 7. HTTP Client Configuration

Uses the shared `DataProvider::HTTP_CONFIG` from the parent spec:

```ruby
module CourtAuction
  class BaseClient
    BASE_URL = "https://www.courtauction.go.kr"

    def initialize
      @conn = Faraday.new(url: BASE_URL) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.request :retry,
          max: 2,
          interval: 1,
          backoff_factor: 2,
          retry_statuses: [502, 503, 504]
        f.options.timeout = 30
        f.options.open_timeout = 5
        f.headers["User-Agent"] = "Mozilla/5.0 (compatible)"
        f.headers["Referer"] = "https://www.courtauction.go.kr/pgj/index.on"
      end
    end

    private

    def post(path, body)
      response = @conn.post(path, body)
      handle_http_errors(response)
      response.body
    rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
      raise DataProvider::ConnectionError, "CourtAuction: #{e.message}"
    end

    def handle_http_errors(response)
      case response.status
      when 200 then nil
      when 403 then raise DataProvider::IpBlockedError, "IP blocked by courtauction.go.kr"
      when 429 then raise DataProvider::RateLimitError, "Rate limited by server"
      when 500..599 then raise DataProvider::ServiceUnavailableError, "Server error: #{response.status}"
      else raise DataProvider::Error, "Unexpected status: #{response.status}"
      end
    end
  end
end
```

---

## 8. GovernmentCourtAuctionAdapter

The main adapter orchestrates the full flow:

```ruby
class GovernmentCourtAuctionAdapter < CourtAuctionAdapter
  def initialize
    @search_client = CourtAuction::SearchClient.new
    @detail_client = CourtAuction::DetailClient.new
    @parser = CourtAuction::ResponseParser.new
    @rate_limiter = CourtAuction::RateLimiter.new
  end

  def fetch_data(case_number:)
    parsed = CourtAuction::CaseNumberParser.parse(case_number)

    @rate_limiter.throttle
    search_result = @search_client.search(**parsed)

    return nil if search_result.empty?

    @rate_limiter.throttle
    detail_result = @detail_client.fetch(
      court_code: search_result[:court_code],
      year: parsed[:year],
      type: parsed[:type],
      number: parsed[:number],
      item_number: search_result[:item_number]
    )

    @parser.parse(search_result: search_result, detail_result: detail_result)
  end
end
```

---

## 9. Testing Strategy

### Unit Tests

**CaseNumberParser** (`test/adapters/court_auction/case_number_parser_test.rb`):
- Valid: "2026타경10001" → `{year: "2026", type: "타경", number: "10001"}`
- Valid with spaces: "2026 타경 10001" → normalized
- Invalid format → `DataProvider::ParseError`

**ResponseParser** (`test/adapters/court_auction/response_parser_test.rb`):
- Happy path: fixture JSON → normalized hash with all expected keys
- Missing required fields → `DataProvider::ParseError`
- Boolean mapping: "Y"→true, "N"→false
- Integer conversion: string amounts → integers
- Output matches MockCourtAuctionAdapter key structure

**SearchClient** (`test/adapters/court_auction/search_client_test.rb`):
- Success: Faraday stub returns fixture JSON → parsed result
- Not found: empty `dlt_list` → nil
- HTTP error mapping (403, 5xx)

**DetailClient** (`test/adapters/court_auction/detail_client_test.rb`):
- Success: fixture JSON → raw detail data
- Structure change: missing expected keys → `SiteStructureChangedError`

**RateLimiter** (`test/adapters/court_auction/rate_limiter_test.rb`):
- Respects minimum interval
- Raises `RateLimitError` when max/min exceeded

### Integration Test

**GovernmentCourtAuctionAdapter** (`test/adapters/government_court_auction_adapter_test.rb`):
- Full flow with stubbed HTTP: search → detail → parsed result
- Result matches MockCourtAuctionAdapter key structure
- Error propagation from each stage

### Test Fixtures

```
test/fixtures/files/
  court_auction_search_response.json     # Sanitized real API response
  court_auction_detail_response.json     # Sanitized real API response
  court_auction_empty_search.json        # Empty result for not-found case
  court_auction_error_response.json      # Error body in 200 response
```

Fixtures will be created by capturing real API responses and removing/replacing personal information (tenant names, specific addresses → generic).

---

## 10. Deployment Notes

### No Playwright/Chromium Required

This scraper uses Faraday HTTP client only. No changes to Dockerfile or Kamal configuration needed. The Playwright deployment section in the parent spec is **not required** for this implementation.

### Docker image stays lean:
- No Chromium (~400MB saved)
- No fonts-nanum package
- No PLAYWRIGHT_BROWSERS_PATH env vars

### Faraday is already installed (Task 1 of infrastructure plan).
