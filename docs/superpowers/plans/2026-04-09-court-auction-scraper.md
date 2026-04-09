# CourtAuction Scraper Implementation Plan

> **SUPERSEDED** — This plan has been replaced by `2026-04-09-court-auction-playwright-redesign.md`.
> The Faraday-based implementation was invalidated when WAF blocking was discovered during live testing.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the stub `GovernmentCourtAuctionAdapter` with a real HTTP-based scraper that calls courtauction.go.kr JSON POST endpoints via Faraday.

**Architecture:** Direct HTTP POST to courtauction.go.kr's WebSquare JSON endpoints (no headless browser). Two-step fetch: search API finds the case, detail API gets full property data. Response is normalized to match MockCourtAuctionAdapter's return schema exactly.

**Tech Stack:** Faraday (already installed), Ruby, Minitest

**Spec:** `docs/superpowers/specs/2026-04-09-court-auction-scraper-design.md`

---

## File Map

### New Files
| File | Responsibility |
|------|---------------|
| `app/adapters/court_auction/case_number_parser.rb` | Parse "2026타경10001" → `{year:, type:, number:}` |
| `app/adapters/court_auction/rate_limiter.rb` | Throttle requests (0.5s interval, 60/min max) |
| `app/adapters/court_auction/base_client.rb` | Shared Faraday connection and HTTP error handling |
| `app/adapters/court_auction/search_client.rb` | Call search API endpoint |
| `app/adapters/court_auction/detail_client.rb` | Call detail API endpoint |
| `app/adapters/court_auction/response_parser.rb` | Normalize API responses to standard hash |
| `test/adapters/court_auction/case_number_parser_test.rb` | Parser tests |
| `test/adapters/court_auction/rate_limiter_test.rb` | Rate limiter tests |
| `test/adapters/court_auction/search_client_test.rb` | Search client tests |
| `test/adapters/court_auction/detail_client_test.rb` | Detail client tests |
| `test/adapters/court_auction/response_parser_test.rb` | Response parser tests |
| `test/adapters/government_court_auction_adapter_integration_test.rb` | Full flow integration test |
| `test/fixtures/files/court_auction_search_response.json` | Search API fixture |
| `test/fixtures/files/court_auction_detail_response.json` | Detail API fixture |
| `test/fixtures/files/court_auction_empty_search.json` | Empty search result fixture |

### Modified Files
| File | Change |
|------|--------|
| `app/adapters/government_court_auction_adapter.rb` | Replace stub with real implementation |

---

## Task 1: Case Number Parser

**Files:**
- Create: `app/adapters/court_auction/case_number_parser.rb`
- Test: `test/adapters/court_auction/case_number_parser_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/adapters/court_auction/case_number_parser_test.rb
require "test_helper"

class CourtAuction::CaseNumberParserTest < ActiveSupport::TestCase
  test "parses standard case number" do
    result = CourtAuction::CaseNumberParser.parse("2026타경10001")
    assert_equal "2026", result[:year]
    assert_equal "타경", result[:type]
    assert_equal "10001", result[:number]
  end

  test "parses case number with spaces" do
    result = CourtAuction::CaseNumberParser.parse("2026 타경 10001")
    assert_equal "2026", result[:year]
    assert_equal "타경", result[:type]
    assert_equal "10001", result[:number]
  end

  test "parses 타채 case type" do
    result = CourtAuction::CaseNumberParser.parse("2025타채5678")
    assert_equal "2025", result[:year]
    assert_equal "타채", result[:type]
    assert_equal "5678", result[:number]
  end

  test "zero-pads short case numbers" do
    result = CourtAuction::CaseNumberParser.parse("2026타경123")
    assert_equal "00123", result[:number]
  end

  test "raises ParseError for invalid format" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse("invalid")
    end
  end

  test "raises ParseError for empty string" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse("")
    end
  end

  test "raises ParseError for nil" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse(nil)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/adapters/court_auction/case_number_parser_test.rb`
Expected: FAIL — `NameError: uninitialized constant CourtAuction`

- [ ] **Step 3: Write the implementation**

```ruby
# app/adapters/court_auction/case_number_parser.rb
module CourtAuction
  class CaseNumberParser
    PATTERN = /\A(\d{4})(타경|타채)(\d+)\z/

    def self.parse(case_number)
      normalized = case_number.to_s.gsub(/\s+/, "")
      match = PATTERN.match(normalized)

      unless match
        raise DataProvider::ParseError, "Invalid case number format: #{case_number.inspect}"
      end

      {
        year: match[1],
        type: match[2],
        number: match[3].rjust(5, "0")
      }
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/adapters/court_auction/case_number_parser_test.rb`
Expected: 7 runs, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/adapters/court_auction/case_number_parser.rb test/adapters/court_auction/case_number_parser_test.rb
git commit -m "feat: add CourtAuction::CaseNumberParser for case number parsing"
```

---

## Task 2: Rate Limiter

**Files:**
- Create: `app/adapters/court_auction/rate_limiter.rb`
- Test: `test/adapters/court_auction/rate_limiter_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/adapters/court_auction/rate_limiter_test.rb
require "test_helper"

class CourtAuction::RateLimiterTest < ActiveSupport::TestCase
  setup do
    @limiter = CourtAuction::RateLimiter.new
  end

  test "first request passes immediately" do
    assert_nothing_raised { @limiter.throttle }
  end

  test "records request times" do
    @limiter.throttle
    assert_equal 1, @limiter.request_count
  end

  test "raises RateLimitError when max per minute exceeded" do
    limiter = CourtAuction::RateLimiter.new(max_per_minute: 2, min_interval: 0)
    limiter.throttle
    limiter.throttle
    assert_raises(DataProvider::RateLimitError) { limiter.throttle }
  end

  test "constants have correct defaults" do
    assert_equal 0.5, CourtAuction::RateLimiter::DEFAULT_MIN_INTERVAL
    assert_equal 60, CourtAuction::RateLimiter::DEFAULT_MAX_PER_MINUTE
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/adapters/court_auction/rate_limiter_test.rb`
Expected: FAIL — `NameError: uninitialized constant CourtAuction::RateLimiter`

- [ ] **Step 3: Write the implementation**

```ruby
# app/adapters/court_auction/rate_limiter.rb
module CourtAuction
  class RateLimiter
    DEFAULT_MIN_INTERVAL = 0.5
    DEFAULT_MAX_PER_MINUTE = 60

    attr_reader :request_count

    def initialize(min_interval: DEFAULT_MIN_INTERVAL, max_per_minute: DEFAULT_MAX_PER_MINUTE)
      @min_interval = min_interval
      @max_per_minute = max_per_minute
      @last_request_at = nil
      @request_times = []
      @request_count = 0
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
      sleep(@min_interval - elapsed) if elapsed < @min_interval
    end

    def check_per_minute_limit
      cutoff = Time.current - 60
      @request_times.reject! { |t| t < cutoff }
      if @request_times.size >= @max_per_minute
        raise DataProvider::RateLimitError,
          "Court auction rate limit: #{@max_per_minute}/min exceeded"
      end
    end

    def record_request
      @last_request_at = Time.current
      @request_times << Time.current
      @request_count += 1
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/adapters/court_auction/rate_limiter_test.rb`
Expected: 4 runs, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/adapters/court_auction/rate_limiter.rb test/adapters/court_auction/rate_limiter_test.rb
git commit -m "feat: add CourtAuction::RateLimiter with configurable throttling"
```

---

## Task 3: Base Client (Shared HTTP)

**Files:**
- Create: `app/adapters/court_auction/base_client.rb`

No dedicated test — tested through SearchClient and DetailClient tests.

- [ ] **Step 1: Write the base client**

```ruby
# app/adapters/court_auction/base_client.rb
module CourtAuction
  class BaseClient
    BASE_URL = "https://www.courtauction.go.kr"

    def initialize
      @conn = build_connection
    end

    private

    def build_connection
      Faraday.new(url: BASE_URL) do |f|
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
        f.headers["Referer"] = "#{BASE_URL}/pgj/index.on"
        f.headers["Accept"] = "application/json"
      end
    end

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
      when 403
        raise DataProvider::IpBlockedError, "IP blocked by courtauction.go.kr"
      when 429
        raise DataProvider::RateLimitError, "Rate limited by courtauction.go.kr"
      when 500..599
        raise DataProvider::ServiceUnavailableError, "courtauction.go.kr server error: #{response.status}"
      else
        raise DataProvider::Error, "courtauction.go.kr unexpected status: #{response.status}"
      end
    end
  end
end
```

- [ ] **Step 2: Commit**

```bash
git add app/adapters/court_auction/base_client.rb
git commit -m "feat: add CourtAuction::BaseClient with Faraday HTTP configuration"
```

---

## Task 4: Test Fixtures

**Files:**
- Create: `test/fixtures/files/court_auction_search_response.json`
- Create: `test/fixtures/files/court_auction_detail_response.json`
- Create: `test/fixtures/files/court_auction_empty_search.json`

- [ ] **Step 1: Create search response fixture**

```json
// test/fixtures/files/court_auction_search_response.json
{
  "totalCnt": 1,
  "dlt_list": [
    {
      "cortOfcCd": "B001001",
      "cortOfcNm": "서울중앙지방법원",
      "csYr": "2026",
      "csCdNm": "타경",
      "csNo": "10001",
      "csDtlNo": "001",
      "gdsDtlAdr": "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호",
      "gdsMdlClsNm": "아파트",
      "aprsAmt": "800000000",
      "lwstSaleAmt": "560000000",
      "gdsStndCd": "0",
      "flbdCnt": "0",
      "prcsCd": "진행"
    }
  ]
}
```

- [ ] **Step 2: Create detail response fixture**

```json
// test/fixtures/files/court_auction_detail_response.json
{
  "cortOfcNm": "서울중앙지방법원",
  "csYr": "2026",
  "csCdNm": "타경",
  "csNo": "10001",
  "bkgsRmk": "해당사항 없음",
  "sprtLandRgstYn": "N",
  "lienRptYn": "N",
  "useAprYn": "Y",
  "wlpttIsuYn": "N",
  "dlt_neRghts": [],
  "dlt_tenants": [],
  "dlt_dxdyDts": [
    {
      "dxdyDt": "20260501",
      "lwstSaleAmt": "560000000",
      "dxdyRslt": ""
    }
  ]
}
```

- [ ] **Step 3: Create empty search fixture**

```json
// test/fixtures/files/court_auction_empty_search.json
{
  "totalCnt": 0,
  "dlt_list": []
}
```

- [ ] **Step 4: Commit**

```bash
git add test/fixtures/files/court_auction_*.json
git commit -m "test: add court auction API response fixtures"
```

---

## Task 5: Search Client

**Files:**
- Create: `app/adapters/court_auction/search_client.rb`
- Test: `test/adapters/court_auction/search_client_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/adapters/court_auction/search_client_test.rb
require "test_helper"

class CourtAuction::SearchClientTest < ActiveSupport::TestCase
  setup do
    @client = CourtAuction::SearchClient.new
    @search_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_response.json"))
    )
    @empty_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
  end

  test "returns parsed search result on success" do
    stub_request(@search_fixture) do
      result = @client.search(year: "2026", type: "타경", number: "10001")
      assert_equal "B001001", result[:court_code]
      assert_equal "001", result[:item_number]
      assert_equal "서울중앙지방법원", result[:court_name]
      assert_equal "아파트", result[:property_type]
      assert_equal "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호", result[:address]
      assert_equal 800_000_000, result[:appraisal_price]
      assert_equal 560_000_000, result[:min_bid_price]
      assert_equal false, result[:is_partial_share]
      assert_equal 0, result[:failed_bid_count]
      assert_equal "진행", result[:status]
    end
  end

  test "returns nil when no results found" do
    stub_request(@empty_fixture) do
      result = @client.search(year: "2026", type: "타경", number: "99999")
      assert_nil result
    end
  end

  test "raises IpBlockedError on 403" do
    stub_error_request(403) do
      assert_raises(DataProvider::IpBlockedError) do
        @client.search(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  test "raises ServiceUnavailableError on 500" do
    stub_error_request(500) do
      assert_raises(DataProvider::ServiceUnavailableError) do
        @client.search(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  test "raises SiteStructureChangedError when expected keys missing" do
    stub_request({"unexpected" => "data"}) do
      assert_raises(DataProvider::SiteStructureChangedError) do
        @client.search(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  private

  def stub_request(body, &block)
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/pgj/pgjsearch/searchControllerMain.on") do
        [200, {"Content-Type" => "application/json"}, body.to_json]
      end
    end
    @client.instance_variable_set(:@conn, build_test_conn(stubs))
    yield
    stubs.verify_stubbed_calls
  end

  def stub_error_request(status, &block)
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/pgj/pgjsearch/searchControllerMain.on") do
        [status, {"Content-Type" => "text/html"}, "Error"]
      end
    end
    @client.instance_variable_set(:@conn, build_test_conn(stubs))
    yield
  end

  def build_test_conn(stubs)
    Faraday.new(url: CourtAuction::BaseClient::BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.adapter :test, stubs
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/adapters/court_auction/search_client_test.rb`
Expected: FAIL — `NameError: uninitialized constant CourtAuction::SearchClient`

- [ ] **Step 3: Write the implementation**

```ruby
# app/adapters/court_auction/search_client.rb
module CourtAuction
  class SearchClient < BaseClient
    SEARCH_PATH = "/pgj/pgjsearch/searchControllerMain.on"
    EXPECTED_KEYS = %w[totalCnt dlt_list].freeze

    def search(year:, type:, number:)
      body = build_search_body(year, type, number)
      response = post(SEARCH_PATH, body)
      validate_structure!(response)
      parse_search_result(response)
    end

    private

    def build_search_body(year, type, number)
      {
        cortAuctnSrchCondCd: "0004601",
        csYr: year,
        csCdNm: type,
        csNo: number,
        pageNo: 1,
        page: 10,
        totalCnt: 0
      }
    end

    def validate_structure!(response)
      missing = EXPECTED_KEYS - response.keys
      if missing.any?
        raise DataProvider::SiteStructureChangedError,
          "Search response missing keys: #{missing.join(', ')}"
      end
    end

    def parse_search_result(response)
      list = response["dlt_list"]
      return nil if list.nil? || list.empty?

      item = list.first
      {
        court_code: item["cortOfcCd"],
        court_name: item["cortOfcNm"],
        item_number: item["csDtlNo"],
        property_type: item["gdsMdlClsNm"],
        address: item["gdsDtlAdr"],
        appraisal_price: item["aprsAmt"].to_i,
        min_bid_price: item["lwstSaleAmt"].to_i,
        is_partial_share: item["gdsStndCd"] != "0",
        failed_bid_count: item["flbdCnt"].to_i,
        status: item["prcsCd"]
      }
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/adapters/court_auction/search_client_test.rb`
Expected: 5 runs, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/adapters/court_auction/search_client.rb test/adapters/court_auction/search_client_test.rb
git commit -m "feat: add CourtAuction::SearchClient for search API calls"
```

---

## Task 6: Detail Client

**Files:**
- Create: `app/adapters/court_auction/detail_client.rb`
- Test: `test/adapters/court_auction/detail_client_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/adapters/court_auction/detail_client_test.rb
require "test_helper"

class CourtAuction::DetailClientTest < ActiveSupport::TestCase
  setup do
    @client = CourtAuction::DetailClient.new
    @detail_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_detail_response.json"))
    )
  end

  test "returns raw detail data on success" do
    stub_request(@detail_fixture) do
      result = @client.fetch(
        court_code: "B001001", year: "2026", type: "타경",
        number: "10001", item_number: "001"
      )
      assert_equal "해당사항 없음", result["bkgsRmk"]
      assert_equal "N", result["lienRptYn"]
      assert_equal "Y", result["useAprYn"]
      assert_kind_of Array, result["dlt_neRghts"]
      assert_kind_of Array, result["dlt_tenants"]
    end
  end

  test "raises SiteStructureChangedError when expected keys missing" do
    stub_request({"unexpected" => "data"}) do
      assert_raises(DataProvider::SiteStructureChangedError) do
        @client.fetch(
          court_code: "B001001", year: "2026", type: "타경",
          number: "10001", item_number: "001"
        )
      end
    end
  end

  private

  def stub_request(body, &block)
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/pgj/pgj15B/selectAuctnCsSrchRslt.on") do
        [200, {"Content-Type" => "application/json"}, body.to_json]
      end
    end
    @client.instance_variable_set(:@conn, build_test_conn(stubs))
    yield
    stubs.verify_stubbed_calls
  end

  def build_test_conn(stubs)
    Faraday.new(url: CourtAuction::BaseClient::BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.adapter :test, stubs
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/adapters/court_auction/detail_client_test.rb`
Expected: FAIL — `NameError: uninitialized constant CourtAuction::DetailClient`

- [ ] **Step 3: Write the implementation**

```ruby
# app/adapters/court_auction/detail_client.rb
module CourtAuction
  class DetailClient < BaseClient
    DETAIL_PATH = "/pgj/pgj15B/selectAuctnCsSrchRslt.on"
    EXPECTED_KEYS = %w[cortOfcNm csNo].freeze

    def fetch(court_code:, year:, type:, number:, item_number:)
      body = {
        cortOfcCd: court_code,
        csYr: year,
        csCdNm: type,
        csNo: number,
        csDtlNo: item_number
      }
      response = post(DETAIL_PATH, body)
      validate_structure!(response)
      response
    end

    private

    def validate_structure!(response)
      missing = EXPECTED_KEYS - response.keys
      if missing.any?
        raise DataProvider::SiteStructureChangedError,
          "Detail response missing keys: #{missing.join(', ')}"
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/adapters/court_auction/detail_client_test.rb`
Expected: 2 runs, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/adapters/court_auction/detail_client.rb test/adapters/court_auction/detail_client_test.rb
git commit -m "feat: add CourtAuction::DetailClient for detail API calls"
```

---

## Task 7: Response Parser

**Files:**
- Create: `app/adapters/court_auction/response_parser.rb`
- Test: `test/adapters/court_auction/response_parser_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/adapters/court_auction/response_parser_test.rb
require "test_helper"

class CourtAuction::ResponseParserTest < ActiveSupport::TestCase
  setup do
    @parser = CourtAuction::ResponseParser.new
    @search_result = {
      court_code: "B001001",
      court_name: "서울중앙지방법원",
      item_number: "001",
      property_type: "아파트",
      address: "서울특별시 강남구 역삼동 100-1",
      appraisal_price: 800_000_000,
      min_bid_price: 560_000_000,
      is_partial_share: false,
      failed_bid_count: 0,
      status: "진행"
    }
    @detail_result = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_detail_response.json"))
    )
  end

  test "parses complete result matching mock adapter schema" do
    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    assert_equal "2026타경10001", result[:case_number]
    assert_equal "서울중앙지방법원", result[:court_name]
    assert_equal "아파트", result[:property_type]
    assert_equal "서울특별시 강남구 역삼동 100-1", result[:address]
    assert_equal 800_000_000, result[:appraisal_price]
    assert_equal 560_000_000, result[:min_bid_price]
    assert_equal "해당사항 없음", result[:remarks]
    assert_equal [], result[:non_extinguished_rights]
    assert_equal [], result[:tenants]
    assert_equal false, result[:separate_land_registry]
    assert_equal false, result[:lien_reported]
    assert_equal true, result[:use_approval]
    assert_equal false, result[:wall_partition_issue]
    assert_equal false, result[:is_partial_share]
  end

  test "includes new fields not in mock" do
    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    assert_equal 0, result[:failed_bid_count]
    assert_equal "진행", result[:status]
    assert_kind_of Array, result[:sale_schedule]
  end

  test "maps boolean Y/N correctly" do
    @detail_result["lienRptYn"] = "Y"
    @detail_result["useAprYn"] = "N"
    @detail_result["sprtLandRgstYn"] = "Y"
    @detail_result["wlpttIsuYn"] = "Y"

    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    assert_equal true, result[:lien_reported]
    assert_equal false, result[:use_approval]
    assert_equal true, result[:separate_land_registry]
    assert_equal true, result[:wall_partition_issue]
  end

  test "parses tenants from detail" do
    @detail_result["dlt_tenants"] = [
      {
        "tnntNm" => "김임차",
        "dpstAmt" => "50000000",
        "mvnDt" => "20240315",
        "dvdReqYn" => "N"
      }
    ]
    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    assert_equal 1, result[:tenants].size
    tenant = result[:tenants].first
    assert_equal "김임차", tenant[:name]
    assert_equal 50_000_000, tenant[:deposit]
    assert_equal "2024-03-15", tenant[:move_in_date]
    assert_equal false, tenant[:dividend_requested]
  end

  test "parses non-extinguished rights" do
    @detail_result["dlt_neRghts"] = [
      { "rghtsNm" => "전세권" },
      { "rghtsNm" => "지상권" }
    ]
    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    assert_equal ["전세권", "지상권"], result[:non_extinguished_rights]
  end

  test "has all keys that MockCourtAuctionAdapter returns" do
    mock_keys = MockCourtAuctionAdapter.new.fetch_data(case_number: "2026타경10001").keys
    result = @parser.parse(search_result: @search_result, detail_result: @detail_result)

    mock_keys.each do |key|
      assert result.key?(key), "Missing key: #{key}"
    end
  end

  test "raises ParseError when required fields missing" do
    @search_result[:court_name] = nil
    assert_raises(DataProvider::ParseError) do
      @parser.parse(search_result: @search_result, detail_result: @detail_result)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/adapters/court_auction/response_parser_test.rb`
Expected: FAIL — `NameError: uninitialized constant CourtAuction::ResponseParser`

- [ ] **Step 3: Write the implementation**

```ruby
# app/adapters/court_auction/response_parser.rb
module CourtAuction
  class ResponseParser
    REQUIRED_FIELDS = %i[case_number court_name address appraisal_price min_bid_price].freeze

    def parse(search_result:, detail_result:)
      result = build_result(search_result, detail_result)
      validate!(result)
      result
    end

    private

    def build_result(search, detail)
      {
        case_number: "#{detail['csYr']}#{detail['csCdNm']}#{detail['csNo']}",
        court_name: search[:court_name],
        property_type: search[:property_type],
        address: search[:address],
        appraisal_price: search[:appraisal_price],
        min_bid_price: search[:min_bid_price],
        remarks: detail["bkgsRmk"] || "",
        non_extinguished_rights: parse_rights(detail["dlt_neRghts"]),
        tenants: parse_tenants(detail["dlt_tenants"]),
        separate_land_registry: yn_to_bool(detail["sprtLandRgstYn"]),
        lien_reported: yn_to_bool(detail["lienRptYn"]),
        use_approval: yn_to_bool(detail["useAprYn"]),
        wall_partition_issue: yn_to_bool(detail["wlpttIsuYn"]),
        is_partial_share: search[:is_partial_share],
        failed_bid_count: search[:failed_bid_count],
        status: search[:status],
        sale_schedule: parse_schedule(detail["dlt_dxdyDts"])
      }
    end

    def parse_rights(rights)
      return [] unless rights.is_a?(Array)
      rights.map { |r| r["rghtsNm"] }.compact
    end

    def parse_tenants(tenants)
      return [] unless tenants.is_a?(Array)
      tenants.map do |t|
        {
          name: t["tnntNm"],
          deposit: t["dpstAmt"]&.to_i,
          move_in_date: parse_date(t["mvnDt"]),
          dividend_requested: yn_to_bool(t["dvdReqYn"])
        }
      end
    end

    def parse_schedule(dates)
      return [] unless dates.is_a?(Array)
      dates.map do |d|
        {
          date: parse_date(d["dxdyDt"]),
          min_price: d["lwstSaleAmt"]&.to_i,
          result: d["dxdyRslt"]
        }
      end
    end

    def yn_to_bool(value)
      value == "Y"
    end

    def parse_date(yyyymmdd)
      return nil unless yyyymmdd.is_a?(String) && yyyymmdd.length == 8
      "#{yyyymmdd[0..3]}-#{yyyymmdd[4..5]}-#{yyyymmdd[6..7]}"
    end

    def validate!(result)
      missing = REQUIRED_FIELDS.select { |f| result[f].blank? }
      if missing.any?
        raise DataProvider::ParseError,
          "Missing required fields: #{missing.join(', ')}"
      end
    end
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/adapters/court_auction/response_parser_test.rb`
Expected: 7 runs, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/adapters/court_auction/response_parser.rb test/adapters/court_auction/response_parser_test.rb
git commit -m "feat: add CourtAuction::ResponseParser normalizing API responses"
```

---

## Task 8: GovernmentCourtAuctionAdapter — Full Integration

**Files:**
- Modify: `app/adapters/government_court_auction_adapter.rb`
- Test: `test/adapters/government_court_auction_adapter_integration_test.rb`

- [ ] **Step 1: Write the failing integration test**

```ruby
# test/adapters/government_court_auction_adapter_integration_test.rb
require "test_helper"

class GovernmentCourtAuctionAdapterIntegrationTest < ActiveSupport::TestCase
  setup do
    @search_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_response.json"))
    )
    @detail_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_detail_response.json"))
    )
    @empty_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
  end

  test "fetch_data returns normalized hash with all expected keys" do
    adapter = build_adapter(@search_fixture, @detail_fixture)
    result = adapter.fetch_data(case_number: "2026타경10001")

    assert_equal "2026타경10001", result[:case_number]
    assert_equal "서울중앙지방법원", result[:court_name]
    assert_equal "아파트", result[:property_type]
    assert_equal 800_000_000, result[:appraisal_price]
    assert_equal 560_000_000, result[:min_bid_price]
    assert_equal false, result[:lien_reported]
    assert_equal true, result[:use_approval]
  end

  test "fetch_data returns nil when case not found" do
    adapter = build_adapter(@empty_fixture, nil)
    result = adapter.fetch_data(case_number: "2026타경99999")
    assert_nil result
  end

  test "result has same keys as mock adapter" do
    adapter = build_adapter(@search_fixture, @detail_fixture)
    real_result = adapter.fetch_data(case_number: "2026타경10001")
    mock_result = MockCourtAuctionAdapter.new.fetch_data(case_number: "2026타경10001")

    mock_result.each_key do |key|
      assert real_result.key?(key), "Real adapter missing key: #{key}"
    end
  end

  test "raises ParseError for invalid case number" do
    adapter = GovernmentCourtAuctionAdapter.new
    assert_raises(DataProvider::ParseError) do
      adapter.fetch_data(case_number: "invalid")
    end
  end

  private

  def build_adapter(search_response, detail_response)
    search_stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/pgj/pgjsearch/searchControllerMain.on") do
        [200, {"Content-Type" => "application/json"}, search_response.to_json]
      end
    end

    detail_stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/pgj/pgj15B/selectAuctnCsSrchRslt.on") do
        [200, {"Content-Type" => "application/json"}, detail_response.to_json]
      end
    end if detail_response

    adapter = GovernmentCourtAuctionAdapter.new
    search_client = adapter.instance_variable_get(:@search_client)
    detail_client = adapter.instance_variable_get(:@detail_client)

    search_conn = Faraday.new(url: CourtAuction::BaseClient::BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.adapter :test, search_stubs
    end
    search_client.instance_variable_set(:@conn, search_conn)

    if detail_response
      detail_conn = Faraday.new(url: CourtAuction::BaseClient::BASE_URL) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.adapter :test, detail_stubs
      end
      detail_client.instance_variable_set(:@conn, detail_conn)
    end

    # Use a no-op rate limiter for tests
    adapter.instance_variable_set(:@rate_limiter, CourtAuction::RateLimiter.new(min_interval: 0, max_per_minute: 1000))

    adapter
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/adapters/government_court_auction_adapter_integration_test.rb`
Expected: FAIL — adapter still delegates to MockCourtAuctionAdapter

- [ ] **Step 3: Replace the adapter implementation**

```ruby
# app/adapters/government_court_auction_adapter.rb
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

    return nil unless search_result

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

- [ ] **Step 4: Run integration test to verify it passes**

Run: `bin/rails test test/adapters/government_court_auction_adapter_integration_test.rb`
Expected: 4 runs, 0 failures

- [ ] **Step 5: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass (existing tests use mock adapter via `CourtAuctionAdapter.for` which defaults to mock)

- [ ] **Step 6: Commit**

```bash
git add app/adapters/government_court_auction_adapter.rb test/adapters/government_court_auction_adapter_integration_test.rb
git commit -m "feat: replace GovernmentCourtAuctionAdapter stub with real HTTP scraper"
```

---

## Summary

| Task | What | Steps |
|------|------|-------|
| 1 | CaseNumberParser | 5 |
| 2 | RateLimiter | 5 |
| 3 | BaseClient (HTTP) | 2 |
| 4 | Test fixtures | 4 |
| 5 | SearchClient | 5 |
| 6 | DetailClient | 5 |
| 7 | ResponseParser | 5 |
| 8 | GovernmentCourtAuctionAdapter integration | 6 |
| **Total** | | **37 steps** |
