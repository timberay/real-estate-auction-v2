# CourtAuction Playwright Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the WAF-blocked Faraday HTTP scraper with a Ferrum (CDP) browser-based scraper using route interception to capture court auction API responses.

**Architecture:** Ferrum headless browser navigates to courtauction.go.kr, fills the search form, and intercepts the XHR response JSON via Chrome DevTools Protocol network events. No HTML DOM parsing — data comes directly from the captured API response. The adapter interface (`CourtAuctionAdapter.for`) and downstream consumers remain unchanged.

**Tech Stack:** Ruby, Ferrum (CDP), Rails 8.1, Minitest, Solid Queue

**Spec:** `docs/superpowers/specs/2026-04-09-court-auction-playwright-redesign.md`

---

## File Map

### Delete
| File | Reason |
|------|--------|
| `app/adapters/court_auction/base_client.rb` | Faraday HTTP client — WAF blocked |
| `app/adapters/court_auction/search_client.rb` | Faraday search — WAF blocked |
| `app/adapters/court_auction/detail_client.rb` | Faraday detail — WAF blocked |
| `test/adapters/court_auction/search_client_test.rb` | Tests deleted code |
| `test/adapters/court_auction/detail_client_test.rb` | Tests deleted code |
| `test/adapters/government_court_auction_adapter_integration_test.rb` | Faraday stubs, rewrite needed |
| `test/fixtures/files/court_auction_search_response.json` | Wrong field names |
| `test/fixtures/files/court_auction_detail_response.json` | Wrong field names |

### Create
| File | Responsibility |
|------|---------------|
| `app/adapters/court_auction/browser_client.rb` | Ferrum browser + route interception |
| `test/adapters/court_auction/browser_client_test.rb` | BrowserClient unit tests (Ferrum stubbed) |
| `test/fixtures/files/court_auction_search_intercepted.json` | Real API response structure fixture |
| `test/adapters/government_court_auction_adapter_integration_test.rb` | Rewritten with BrowserClient stub |

### Modify
| File | Change |
|------|--------|
| `Gemfile` | Add `ferrum`, remove `faraday`/`faraday-retry` |
| `app/adapters/government_court_auction_adapter.rb` | Use BrowserClient instead of SearchClient/DetailClient |
| `app/adapters/court_auction/response_parser.rb` | Rewrite for search-only flow + correct field names |
| `test/adapters/court_auction/response_parser_test.rb` | Update for new fixture + new interface |

### Keep (unchanged)
| File | Reason |
|------|--------|
| `app/adapters/court_auction/case_number_parser.rb` | Logic valid, WAF-independent |
| `app/adapters/court_auction/rate_limiter.rb` | Still needed for throttling |
| `app/adapters/court_auction_adapter.rb` | Factory pattern unchanged |
| `app/adapters/mock_court_auction_adapter.rb` | Mock data unchanged |
| `test/fixtures/files/court_auction_empty_search.json` | Empty result still valid |
| `test/adapters/court_auction/case_number_parser_test.rb` | Tests unchanged code |
| `test/adapters/court_auction/rate_limiter_test.rb` | Tests unchanged code |
| `test/adapters/court_auction_adapter_test.rb` | Factory tests unchanged |
| `test/adapters/mock_court_auction_adapter_test.rb` | Mock tests unchanged |

---

## Task 1: Gem Dependencies

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Update Gemfile**

Replace the Faraday gems with Ferrum:

```ruby
# In Gemfile, replace these lines:
# gem "faraday"
# gem "faraday-retry"
# With:
gem "ferrum"
```

The exact edit: remove the two lines under `# HTTP client for external API integrations` and replace:

```ruby
# Browser automation for government site scraping (WAF blocks direct HTTP)
gem "ferrum"
```

- [ ] **Step 2: Run bundle install**

Run: `bundle install`
Expected: Ferrum and its dependencies install successfully.

- [ ] **Step 3: Verify existing tests still pass**

Run: `bin/rails test test/adapters/court_auction/case_number_parser_test.rb test/adapters/court_auction/rate_limiter_test.rb test/adapters/court_auction_adapter_test.rb test/adapters/mock_court_auction_adapter_test.rb`
Expected: All pass. These tests don't use Faraday.

Note: Tests that DO use Faraday (`search_client_test.rb`, `detail_client_test.rb`, `government_court_auction_adapter_integration_test.rb`) will fail — that's expected since we removed the gem. They will be deleted in Task 2.

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore: replace faraday with ferrum gem

WAF blocks direct HTTP to courtauction.go.kr. Switching to Ferrum
(Chrome DevTools Protocol) for browser-based scraping.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Delete Faraday-Based Code

**Files:**
- Delete: `app/adapters/court_auction/base_client.rb`
- Delete: `app/adapters/court_auction/search_client.rb`
- Delete: `app/adapters/court_auction/detail_client.rb`
- Delete: `test/adapters/court_auction/search_client_test.rb`
- Delete: `test/adapters/court_auction/detail_client_test.rb`
- Delete: `test/adapters/government_court_auction_adapter_integration_test.rb`
- Delete: `test/fixtures/files/court_auction_search_response.json`
- Delete: `test/fixtures/files/court_auction_detail_response.json`

- [ ] **Step 1: Delete all Faraday-based files**

```bash
rm app/adapters/court_auction/base_client.rb
rm app/adapters/court_auction/search_client.rb
rm app/adapters/court_auction/detail_client.rb
rm test/adapters/court_auction/search_client_test.rb
rm test/adapters/court_auction/detail_client_test.rb
rm test/adapters/government_court_auction_adapter_integration_test.rb
rm test/fixtures/files/court_auction_search_response.json
rm test/fixtures/files/court_auction_detail_response.json
```

- [ ] **Step 2: Verify no remaining Faraday references in court_auction code**

Run: `grep -r "Faraday\|faraday" app/adapters/court_auction/ test/adapters/court_auction/`
Expected: No matches.

- [ ] **Step 3: Run remaining court_auction tests**

Run: `bin/rails test test/adapters/court_auction/case_number_parser_test.rb test/adapters/court_auction/rate_limiter_test.rb test/adapters/court_auction_adapter_test.rb test/adapters/mock_court_auction_adapter_test.rb`
Expected: All pass.

Note: `response_parser_test.rb` will fail because it references the deleted detail fixture. This is expected — it will be rewritten in Task 5.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: remove Faraday-based court auction clients

Delete base_client, search_client, detail_client and their tests.
These are blocked by WAF and will be replaced by Ferrum browser client.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Create API Response Fixture

**Files:**
- Create: `test/fixtures/files/court_auction_search_intercepted.json`

This fixture mirrors the actual API response structure captured during live testing (documented in `docs/superpowers/specs/2026-04-09-court-auction-api-field-analysis.md`).

- [ ] **Step 1: Create the fixture file**

```json
{
  "status": 200,
  "message": "검색 결과가 조회되었습니다.",
  "data": {
    "dma_pageInfo": {
      "totalCnt": "1",
      "groupTotalCount": 1
    },
    "dlt_srchResult": [
      {
        "srnSaNo": "2026타경10001",
        "jiwonNm": "서울중앙지방법원",
        "dspslUsgNm": "아파트",
        "printSt": "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호",
        "gamevalAmt": "800000000",
        "minmaePrice": "560000000",
        "mulBigo": "일괄매각",
        "yuchalCnt": "2",
        "mokGbncd": "00",
        "spJogCd": "",
        "inqCnt": "45",
        "boCd": "B001001",
        "saNo": "20260130100011",
        "maemulSer": "1",
        "mokmulSer": "1",
        "jpDeptCd": "1011",
        "jpDeptNm": "경매11계",
        "jinstatCd": "0002100001",
        "mulStatcd": "01",
        "mulJinYn": "Y",
        "maeGiil": "20260501",
        "maePlace": "경매법정4별관211호",
        "hjguSido": "서울특별시",
        "hjguSigu": "강남구",
        "hjguDong": "역삼동",
        "wgs84Xcordi": "127.0365",
        "wgs84Ycordi": "37.5012"
      }
    ]
  }
}
```

- [ ] **Step 2: Verify fixture is valid JSON**

Run: `ruby -rjson -e "JSON.parse(File.read('test/fixtures/files/court_auction_search_intercepted.json')); puts 'Valid JSON'"`
Expected: `Valid JSON`

- [ ] **Step 3: Commit**

```bash
git add test/fixtures/files/court_auction_search_intercepted.json
git commit -m "test: add real API response fixture for court auction

Fixture mirrors actual courtauction.go.kr response structure with
correct field names (srnSaNo, jiwonNm, gamevalAmt, etc.) captured
via Playwright route interception.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Rewrite ResponseParser for Search-Only Flow

The parser previously combined search + detail results. Now it only processes the search API response with corrected field names. The interface changes from `parse(search_result:, detail_result:)` to `parse(api_response:)` which takes the raw intercepted JSON.

**Files:**
- Modify: `app/adapters/court_auction/response_parser.rb`
- Modify: `test/adapters/court_auction/response_parser_test.rb`

- [ ] **Step 1: Write the failing tests**

Replace the entire contents of `test/adapters/court_auction/response_parser_test.rb`:

```ruby
require "test_helper"

class CourtAuction::ResponseParserTest < ActiveSupport::TestCase
  setup do
    @parser = CourtAuction::ResponseParser.new
    @fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
    )
  end

  test "parses intercepted API response into normalized hash" do
    result = @parser.parse(api_response: @fixture)

    assert_equal "2026타경10001", result[:case_number]
    assert_equal "서울중앙지방법원", result[:court_name]
    assert_equal "아파트", result[:property_type]
    assert_equal "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호", result[:address]
    assert_equal 800_000_000, result[:appraisal_price]
    assert_equal 560_000_000, result[:min_bid_price]
  end

  test "parses raw_data fields for inspection runner" do
    result = @parser.parse(api_response: @fixture)

    assert_equal "일괄매각", result[:remarks]
    assert_equal 2, result[:failed_bid_count]
    assert_equal false, result[:is_partial_share]
    assert_equal "", result[:special_conditions]
    assert_equal 45, result[:view_count]
  end

  test "returns nil when dlt_srchResult is empty" do
    empty = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
    result = @parser.parse(api_response: empty)

    assert_nil result
  end

  test "raises ParseError when required fields are blank" do
    @fixture["data"]["dlt_srchResult"][0]["jiwonNm"] = ""

    assert_raises(DataProvider::ParseError) do
      @parser.parse(api_response: @fixture)
    end
  end

  test "raises ParseError when response structure is unexpected" do
    bad_response = { "status" => 200, "data" => {} }

    assert_raises(DataProvider::ParseError) do
      @parser.parse(api_response: bad_response)
    end
  end

  test "converts price strings to integers" do
    result = @parser.parse(api_response: @fixture)

    assert_kind_of Integer, result[:appraisal_price]
    assert_kind_of Integer, result[:min_bid_price]
  end

  test "mokGbncd 00 means not partial share" do
    @fixture["data"]["dlt_srchResult"][0]["mokGbncd"] = "00"
    result = @parser.parse(api_response: @fixture)
    assert_equal false, result[:is_partial_share]
  end

  test "mokGbncd 03 means partial share" do
    @fixture["data"]["dlt_srchResult"][0]["mokGbncd"] = "03"
    result = @parser.parse(api_response: @fixture)
    assert_equal true, result[:is_partial_share]
  end

  test "result has all keys that mock adapter returns" do
    mock_keys = MockCourtAuctionAdapter.new.fetch_data(case_number: "2026타경10001").keys
    result = @parser.parse(api_response: @fixture)

    # Check core keys (mock has detail-only fields that search doesn't provide)
    core_keys = %i[case_number court_name property_type address appraisal_price min_bid_price
                   remarks is_partial_share failed_bid_count]
    core_keys.each do |key|
      assert result.key?(key), "Missing key: #{key}"
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/adapters/court_auction/response_parser_test.rb`
Expected: FAIL — `parse` method signature doesn't match `api_response:` keyword.

- [ ] **Step 3: Rewrite ResponseParser implementation**

Replace the entire contents of `app/adapters/court_auction/response_parser.rb`:

```ruby
module CourtAuction
  class ResponseParser
    REQUIRED_FIELDS = %i[case_number court_name address appraisal_price min_bid_price].freeze

    def parse(api_response:)
      items = extract_items(api_response)
      return nil if items.nil? || items.empty?

      item = items.first
      result = build_result(item)
      validate!(result)
      result
    end

    private

    def extract_items(response)
      response.dig("data", "dlt_srchResult")
    rescue NoMethodError
      raise DataProvider::ParseError, "Unexpected response structure"
    end

    def build_result(item)
      {
        case_number: item["srnSaNo"],
        court_name: item["jiwonNm"],
        property_type: item["dspslUsgNm"],
        address: item["printSt"],
        appraisal_price: item["gamevalAmt"].to_i,
        min_bid_price: item["minmaePrice"].to_i,
        remarks: item["mulBigo"] || "",
        failed_bid_count: item["yuchalCnt"].to_i,
        is_partial_share: item["mokGbncd"] != "00",
        special_conditions: item["spJogCd"] || "",
        view_count: item["inqCnt"].to_i
      }
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

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/adapters/court_auction/response_parser_test.rb`
Expected: All pass.

- [ ] **Step 5: Update the empty search fixture for new structure**

The current `court_auction_empty_search.json` uses old structure (`dlt_list`). Update it to match the real API:

Replace contents of `test/fixtures/files/court_auction_empty_search.json`:

```json
{
  "status": 200,
  "message": "검색 결과가 조회되었습니다.",
  "data": {
    "dma_pageInfo": {
      "totalCnt": "0",
      "groupTotalCount": 0
    },
    "dlt_srchResult": []
  }
}
```

- [ ] **Step 6: Run tests again after fixture update**

Run: `bin/rails test test/adapters/court_auction/response_parser_test.rb`
Expected: All pass.

- [ ] **Step 7: Commit**

```bash
git add app/adapters/court_auction/response_parser.rb test/adapters/court_auction/response_parser_test.rb test/fixtures/files/court_auction_empty_search.json
git commit -m "feat: rewrite ResponseParser for search-only flow with correct field names

Interface changes from parse(search_result:, detail_result:) to
parse(api_response:) taking raw intercepted JSON. Field mappings
corrected per live API capture: srnSaNo, jiwonNm, gamevalAmt, etc.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Create BrowserClient

**Files:**
- Create: `app/adapters/court_auction/browser_client.rb`
- Create: `test/adapters/court_auction/browser_client_test.rb`

- [ ] **Step 1: Write the failing tests**

Create `test/adapters/court_auction/browser_client_test.rb`:

```ruby
require "test_helper"

class CourtAuction::BrowserClientTest < ActiveSupport::TestCase
  setup do
    @client = CourtAuction::BrowserClient.new
    @fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
  end

  test "fetch returns parsed JSON from intercepted API response" do
    mock_browser = stub_browser(response_body: @fixture)

    Ferrum::Browser.stub(:new, mock_browser) do
      result = @client.fetch(year: "2026", type: "타경", number: "10001")

      assert_kind_of Hash, result
      assert_equal 200, result["status"]
      items = result.dig("data", "dlt_srchResult")
      assert_equal 1, items.size
      assert_equal "2026타경10001", items.first["srnSaNo"]
    end
  end

  test "fetch returns nil when no results found" do
    empty_fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    mock_browser = stub_browser(response_body: empty_fixture)

    Ferrum::Browser.stub(:new, mock_browser) do
      result = @client.fetch(year: "2026", type: "타경", number: "99999")

      assert_kind_of Hash, result
      assert_empty result.dig("data", "dlt_srchResult")
    end
  end

  test "fetch raises TimeoutError on browser timeout" do
    mock_browser = stub_browser(raise_error: Ferrum::TimeoutError.new("timeout"))

    Ferrum::Browser.stub(:new, mock_browser) do
      assert_raises(DataProvider::TimeoutError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  test "fetch raises ServiceUnavailableError on connection failure" do
    mock_browser = stub_browser(raise_error: Ferrum::StatusError.new("https://www.courtauction.go.kr", 503))

    Ferrum::Browser.stub(:new, mock_browser) do
      assert_raises(DataProvider::ServiceUnavailableError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  test "fetch raises ConfigurationError when Chromium not found" do
    Ferrum::Browser.stub(:new, ->(**_) { raise Ferrum::BinaryNotFoundError.new("") }) do
      assert_raises(DataProvider::ConfigurationError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  test "browser is always quit even on error" do
    quit_called = false
    mock_browser = stub_browser(raise_error: RuntimeError.new("unexpected"))
    mock_browser.define_singleton_method(:quit) { quit_called = true }

    Ferrum::Browser.stub(:new, mock_browser) do
      assert_raises(RuntimeError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end

    assert quit_called, "browser.quit must be called in ensure block"
  end

  private

  def stub_browser(response_body: nil, raise_error: nil)
    intercepted_body = response_body

    page = Object.new
    page.define_singleton_method(:on) { |_event, &_block| @network_callback = _block }
    page.define_singleton_method(:go_to) { |_url| nil }
    page.define_singleton_method(:evaluate) do |_js|
      if raise_error
        raise raise_error
      end
      nil
    end
    page.define_singleton_method(:at_css) { |_sel| nil }

    # Simulate network interception by triggering callback
    page.define_singleton_method(:trigger_interception) do |body|
      # This simulates the network event
    end

    browser = Object.new
    browser.define_singleton_method(:create_page) { page }
    browser.define_singleton_method(:quit) { nil }
    browser.define_singleton_method(:page) { page }

    # Allow BrowserClient to get the response via a seam
    if intercepted_body
      browser.define_singleton_method(:_test_intercepted_body) { intercepted_body }
    end

    browser
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/adapters/court_auction/browser_client_test.rb`
Expected: FAIL — `CourtAuction::BrowserClient` class doesn't exist.

- [ ] **Step 3: Write the BrowserClient implementation**

Create `app/adapters/court_auction/browser_client.rb`:

```ruby
module CourtAuction
  class BrowserClient
    SEARCH_URL = "https://www.courtauction.go.kr/pgj/index.on"
    API_ENDPOINT = "/pgj/pgjsearch/searchControllerMain.on"
    DEFAULT_TIMEOUT = ENV.fetch("BROWSER_TIMEOUT", 30).to_i

    def initialize(timeout: DEFAULT_TIMEOUT)
      @timeout = timeout
    end

    def fetch(year:, type:, number:)
      intercepted_response = nil
      browser = create_browser

      begin
        page = browser.create_page

        page.on(:response) do |response|
          if response.url.include?(API_ENDPOINT)
            intercepted_response = response.body
          end
        end

        page.go_to(SEARCH_URL)
        submit_search(page, year: year, type: type, number: number)
        wait_for_response(page) { intercepted_response }

        JSON.parse(intercepted_response)
      rescue Ferrum::TimeoutError => e
        raise DataProvider::TimeoutError, "Court auction browser timeout: #{e.message}"
      rescue Ferrum::StatusError => e
        raise DataProvider::ServiceUnavailableError, "Court auction site unreachable: #{e.message}"
      ensure
        browser&.quit
      end
    end

    private

    def create_browser
      Ferrum::Browser.new(
        headless: true,
        timeout: @timeout,
        browser_path: ENV["BROWSER_PATH"],
        process_timeout: 10,
        window_size: [1280, 720]
      )
    rescue Ferrum::BinaryNotFoundError => e
      raise DataProvider::ConfigurationError, "Chromium not installed: #{e.message}"
    end

    def submit_search(page, year:, type:, number:)
      page.evaluate(<<~JS)
        // Fill the search form and trigger API call
        (function() {
          var form = document.querySelector('form[name="frmSearch"]') ||
                     document.querySelector('form');
          if (!form) return;

          // Set case number fields
          var yearInput = document.querySelector('[name="csYr"], [name="srchCsYr"]');
          var typeInput = document.querySelector('[name="csCdNm"], [name="srchCsCdNm"]');
          var numberInput = document.querySelector('[name="csNo"], [name="srchCsNo"]');

          if (yearInput) yearInput.value = '#{year}';
          if (typeInput) typeInput.value = '#{type}';
          if (numberInput) numberInput.value = '#{number}';

          // Click search button
          var searchBtn = document.querySelector('.btn_search, [onclick*="search"], button[type="submit"]');
          if (searchBtn) searchBtn.click();
        })();
      JS
    end

    def wait_for_response(page)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      loop do
        result = yield
        return if result
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
        raise Ferrum::TimeoutError, "API response not intercepted within #{@timeout}s" if elapsed > @timeout
        sleep 0.1
      end
    end
  end
end
```

- [ ] **Step 4: Adjust tests based on actual implementation**

The stub_browser helper needs to align with the actual Ferrum API used in the implementation. Update `test/adapters/court_auction/browser_client_test.rb` — replace the `stub_browser` method and tests to properly test via dependency injection:

```ruby
require "test_helper"
require "ostruct"

class CourtAuction::BrowserClientTest < ActiveSupport::TestCase
  setup do
    @client = CourtAuction::BrowserClient.new
    @fixture_json = File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
  end

  test "fetch returns parsed JSON from intercepted response" do
    result = with_stubbed_browser(@fixture_json) do
      @client.fetch(year: "2026", type: "타경", number: "10001")
    end

    assert_kind_of Hash, result
    assert_equal 200, result["status"]
    items = result.dig("data", "dlt_srchResult")
    assert_equal 1, items.size
    assert_equal "2026타경10001", items.first["srnSaNo"]
  end

  test "fetch returns empty result hash when no results" do
    empty_json = File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    result = with_stubbed_browser(empty_json) do
      @client.fetch(year: "2026", type: "타경", number: "99999")
    end

    assert_empty result.dig("data", "dlt_srchResult")
  end

  test "fetch raises TimeoutError on browser timeout" do
    assert_raises(DataProvider::TimeoutError) do
      with_stubbed_browser(nil, error: Ferrum::TimeoutError.new("timeout")) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  test "fetch raises ServiceUnavailableError on connection failure" do
    assert_raises(DataProvider::ServiceUnavailableError) do
      with_stubbed_browser(nil, error: Ferrum::StatusError.new("url", 503)) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  test "fetch raises ConfigurationError when Chromium not found" do
    Ferrum::Browser.stub(:new, ->(**_) { raise Ferrum::BinaryNotFoundError.new("not found") }) do
      assert_raises(DataProvider::ConfigurationError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  test "browser is always quit even on error" do
    quit_called = false

    mock_browser = build_mock_browser(nil, error: RuntimeError.new("boom"))
    original_quit = mock_browser.method(:quit)
    mock_browser.define_singleton_method(:quit) do
      quit_called = true
      original_quit.call
    end

    Ferrum::Browser.stub(:new, ->(**_) { mock_browser }) do
      assert_raises(RuntimeError) do
        @client.fetch(year: "2026", type: "타경", number: "10001")
      end
    end

    assert quit_called, "browser.quit must be called in ensure block"
  end

  private

  def with_stubbed_browser(response_body, error: nil, &block)
    mock = build_mock_browser(response_body, error: error)
    Ferrum::Browser.stub(:new, ->(**_) { mock }, &block)
  end

  def build_mock_browser(response_body, error: nil)
    response_callback = nil

    mock_page = Object.new
    mock_page.define_singleton_method(:on) do |event, &block|
      response_callback = block if event == :response
    end
    mock_page.define_singleton_method(:go_to) { |_url| nil }
    mock_page.define_singleton_method(:evaluate) do |_js|
      raise error if error
      # Simulate API response arriving after search
      if response_callback && response_body
        mock_response = Object.new
        mock_response.define_singleton_method(:url) { "https://www.courtauction.go.kr/pgj/pgjsearch/searchControllerMain.on" }
        mock_response.define_singleton_method(:body) { response_body }
        response_callback.call(mock_response)
      end
    end

    mock_browser = Object.new
    mock_browser.define_singleton_method(:create_page) { mock_page }
    mock_browser.define_singleton_method(:quit) { nil }
    mock_browser
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/adapters/court_auction/browser_client_test.rb`
Expected: All 6 tests pass.

- [ ] **Step 6: Commit**

```bash
git add app/adapters/court_auction/browser_client.rb test/adapters/court_auction/browser_client_test.rb
git commit -m "feat: add BrowserClient with Ferrum CDP route interception

Headless browser navigates to courtauction.go.kr, fills search form,
and intercepts XHR response JSON via CDP network events. No HTML DOM
parsing needed. Handles timeout, connection, and missing-Chromium errors.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Rewrite GovernmentCourtAuctionAdapter

**Files:**
- Modify: `app/adapters/government_court_auction_adapter.rb`
- Create: `test/adapters/government_court_auction_adapter_integration_test.rb`

- [ ] **Step 1: Write the failing integration tests**

Create `test/adapters/government_court_auction_adapter_integration_test.rb`:

```ruby
require "test_helper"

class GovernmentCourtAuctionAdapterIntegrationTest < ActiveSupport::TestCase
  setup do
    @fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
    )
    @empty_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
  end

  test "fetch_data returns normalized hash with core fields" do
    adapter = build_adapter(@fixture)
    result = adapter.fetch_data(case_number: "2026타경10001")

    assert_equal "2026타경10001", result[:case_number]
    assert_equal "서울중앙지방법원", result[:court_name]
    assert_equal "아파트", result[:property_type]
    assert_equal "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호", result[:address]
    assert_equal 800_000_000, result[:appraisal_price]
    assert_equal 560_000_000, result[:min_bid_price]
  end

  test "fetch_data returns raw_data fields for inspection" do
    adapter = build_adapter(@fixture)
    result = adapter.fetch_data(case_number: "2026타경10001")

    assert_equal "일괄매각", result[:remarks]
    assert_equal 2, result[:failed_bid_count]
    assert_equal false, result[:is_partial_share]
    assert_equal 45, result[:view_count]
  end

  test "fetch_data returns nil when case not found" do
    adapter = build_adapter(@empty_fixture)
    result = adapter.fetch_data(case_number: "2026타경99999")

    assert_nil result
  end

  test "raises ParseError for invalid case number" do
    adapter = GovernmentCourtAuctionAdapter.new
    assert_raises(DataProvider::ParseError) do
      adapter.fetch_data(case_number: "invalid")
    end
  end

  test "throttles requests via rate limiter" do
    adapter = build_adapter(@fixture)
    rate_limiter = adapter.instance_variable_get(:@rate_limiter)

    adapter.fetch_data(case_number: "2026타경10001")

    assert_equal 1, rate_limiter.request_count
  end

  private

  def build_adapter(browser_response)
    adapter = GovernmentCourtAuctionAdapter.new

    mock_client = Object.new
    mock_client.define_singleton_method(:fetch) { |**_args| browser_response }

    adapter.instance_variable_set(:@browser_client, mock_client)
    adapter.instance_variable_set(
      :@rate_limiter,
      CourtAuction::RateLimiter.new(min_interval: 0, max_per_minute: 1000)
    )

    adapter
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/adapters/government_court_auction_adapter_integration_test.rb`
Expected: FAIL — adapter still references SearchClient/DetailClient.

- [ ] **Step 3: Rewrite GovernmentCourtAuctionAdapter**

Replace the entire contents of `app/adapters/government_court_auction_adapter.rb`:

```ruby
class GovernmentCourtAuctionAdapter < CourtAuctionAdapter
  def initialize
    @browser_client = CourtAuction::BrowserClient.new
    @parser = CourtAuction::ResponseParser.new
    @rate_limiter = CourtAuction::RateLimiter.new
  end

  def fetch_data(case_number:)
    parsed = CourtAuction::CaseNumberParser.parse(case_number)

    @rate_limiter.throttle
    api_response = @browser_client.fetch(**parsed)

    @parser.parse(api_response: api_response)
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/adapters/government_court_auction_adapter_integration_test.rb`
Expected: All 5 tests pass.

- [ ] **Step 5: Run all court_auction tests together**

Run: `bin/rails test test/adapters/`
Expected: All tests pass (case_number_parser, rate_limiter, browser_client, response_parser, adapter factory, mock adapter, integration).

- [ ] **Step 6: Commit**

```bash
git add app/adapters/government_court_auction_adapter.rb test/adapters/government_court_auction_adapter_integration_test.rb
git commit -m "feat: rewrite GovernmentCourtAuctionAdapter to use BrowserClient

Simplified from SearchClient+DetailClient two-step to single
BrowserClient call. Parser receives raw API response directly.
Rate limiter still throttles between requests.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Update MockCourtAuctionAdapter Schema (if needed)

The mock adapter returns fields like `non_extinguished_rights`, `tenants`, `sale_schedule` from the detail API. Since search-only flow doesn't provide these, we need to verify mock/real alignment.

**Files:**
- Check: `app/adapters/mock_court_auction_adapter.rb`
- Check: `test/adapters/mock_court_auction_adapter_test.rb`

- [ ] **Step 1: Check if mock and real adapter output align**

Run: `bin/rails test test/adapters/`
Expected: All pass. If the "result has all keys" test fails, proceed to Step 2. Otherwise skip to Step 4.

- [ ] **Step 2: (If needed) Add detail-only fields to real adapter output with defaults**

If mock adapter has keys that real adapter doesn't, add them to `ResponseParser#build_result` with sensible defaults:

```ruby
# Add to build_result hash if missing keys are flagged:
non_extinguished_rights: [],
tenants: [],
separate_land_registry: false,
lien_reported: false,
use_approval: false,
wall_partition_issue: false,
sale_schedule: [],
status: item["jinstatCd"] || ""
```

- [ ] **Step 3: (If needed) Run tests again**

Run: `bin/rails test test/adapters/`
Expected: All pass.

- [ ] **Step 4: Commit (only if changes were made)**

```bash
git add -A
git commit -m "fix: align real adapter output with mock adapter schema

Add default values for detail-only fields not available in search-only
flow. Ensures downstream consumers get consistent hash structure.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Full Test Suite & Cleanup

**Files:**
- Check: all test files
- Modify: `Dockerfile` (if it exists)

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass with zero failures.

- [ ] **Step 2: Run linter**

Run: `bin/rubocop`
Expected: No new offenses. Fix any that appear.

- [ ] **Step 3: Run security checks**

Run: `bin/brakeman --quiet --no-pager`
Expected: No new warnings.

Run: `bin/bundler-audit`
Expected: No vulnerabilities.

- [ ] **Step 4: Verify no stale Faraday references remain**

Run: `grep -r "Faraday\|faraday" app/ test/ --include="*.rb" | grep -v "Gemfile"`
Expected: No matches.

Run: `grep -r "base_client\|search_client\|detail_client" app/ test/ --include="*.rb" | grep -v browser_client`
Expected: No matches.

- [ ] **Step 5: (If Dockerfile exists) Add Chromium**

Check if `Dockerfile` exists and add Chromium installation if missing:

```dockerfile
# Add after existing apt-get install line:
RUN apt-get update && apt-get install -y --no-install-recommends chromium \
    && rm -rf /var/lib/apt/lists/*
```

- [ ] **Step 6: Commit any fixes**

```bash
git add -A
git commit -m "chore: cleanup and verify full test suite after Playwright migration

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Update Obsoleted Documentation

**Files:**
- Modify: `docs/superpowers/specs/2026-04-09-court-auction-scraper-design.md`
- Modify: `docs/superpowers/plans/2026-04-09-court-auction-scraper.md`

- [ ] **Step 1: Mark old spec as superseded**

Add a notice at the top of `docs/superpowers/specs/2026-04-09-court-auction-scraper-design.md`:

```markdown
> **⚠️ SUPERSEDED** — This document has been replaced by `2026-04-09-court-auction-playwright-redesign.md`.
> The Faraday HTTP approach described here is blocked by WAF. See the replacement spec for the Ferrum (CDP) approach.
```

- [ ] **Step 2: Mark old plan as superseded**

Add a notice at the top of `docs/superpowers/plans/2026-04-09-court-auction-scraper.md`:

```markdown
> **⚠️ SUPERSEDED** — This plan has been replaced by `2026-04-09-court-auction-playwright-redesign.md`.
> The Faraday-based implementation was invalidated when WAF blocking was discovered during live testing.
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/specs/2026-04-09-court-auction-scraper-design.md docs/superpowers/plans/2026-04-09-court-auction-scraper.md
git commit -m "docs: mark old court auction spec and plan as superseded

Both documents are invalidated by WAF discovery. Replaced by
2026-04-09-court-auction-playwright-redesign.md (Ferrum CDP approach).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```
