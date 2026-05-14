# Criteria Search HTTP Client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace browser-based criteria search with a direct HTTP client that accepts user address + max bid price, queries the court auction API, and returns paginated results.

**Architecture:** New `CriteriaSearchClient` (Faraday HTTP) replaces `BrowserClient` for criteria search. The adapter delegates to the new client. The service accepts `address:` and `max_bid_price:` directly, maps address → region code, max_bid_price → next price tier, and persists results.

**Tech Stack:** Ruby, Faraday, Minitest, WebMock

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `app/adapters/court_auction/criteria_search_client.rb` | HTTP client for criteria search API with pagination |
| Create | `test/adapters/court_auction/criteria_search_client_test.rb` | Unit tests with WebMock |
| Create | `test/fixtures/files/court_auction_criteria_search_page1.json` | Fixture: page 1 response (totalCnt > 10) |
| Create | `test/fixtures/files/court_auction_criteria_search_page2.json` | Fixture: page 2 response |
| Modify | `app/adapters/court_auction_adapter.rb:10` | Update `search_by_criteria` signature |
| Modify | `app/adapters/government_court_auction_adapter.rb:31-39` | Use `CriteriaSearchClient` instead of `BrowserClient` |
| Modify | `app/services/court_auction_search_service.rb` | Accept `address:`, `max_bid_price:` params |
| Modify | `test/services/court_auction_search_service_test.rb` | Update tests for new interface |

---

### Task 1: Create CriteriaSearchClient — failing test

**Files:**
- Create: `test/fixtures/files/court_auction_criteria_search_page1.json`
- Create: `test/fixtures/files/court_auction_criteria_search_page2.json`
- Create: `test/adapters/court_auction/criteria_search_client_test.rb`

- [ ] **Step 1: Create fixture for page 1 response (totalCnt=12, 10 items)**

Create `test/fixtures/files/court_auction_criteria_search_page1.json`:

```json
{
  "status": 200,
  "message": "검색 결과가 조회되었습니다.",
  "data": {
    "dma_pageInfo": {
      "pageNo": 1,
      "pageSize": 10,
      "totalYn": "Y",
      "startRowNo": 1,
      "totalCnt": "12",
      "groupTotalCount": 12
    },
    "ipcheck": true,
    "dlt_srchResult": [
      {
        "docid": "B00021120240130100011",
        "srnSaNo": "2024타경10001",
        "boCd": "B000211",
        "saNo": "20240130100011",
        "maemulSer": "1",
        "mokmulSer": "1",
        "printSt": "서울특별시 강남구 역삼동 100-1",
        "gamevalAmt": "120000000",
        "minmaePrice": "96000000",
        "yuchalCnt": "1",
        "ipchalGbncd": "000331",
        "maeGiil": "20260420",
        "maegyuljGiil": "20260427",
        "jiwonNm": "서울동부지방법원",
        "dspslUsgNm": "아파트",
        "mulJinYn": "Y",
        "mulBigo": ""
      },
      {
        "docid": "B00021120240130100022",
        "srnSaNo": "2024타경10002",
        "boCd": "B000211",
        "saNo": "20240130100022",
        "maemulSer": "2",
        "mokmulSer": "1",
        "printSt": "서울특별시 서초구 서초동 200-2",
        "gamevalAmt": "140000000",
        "minmaePrice": "112000000",
        "yuchalCnt": "0",
        "ipchalGbncd": "000332",
        "maeGiil": "20260422",
        "maegyuljGiil": "20260429",
        "jiwonNm": "서울동부지방법원",
        "dspslUsgNm": "빌라",
        "mulJinYn": "Y",
        "mulBigo": "일괄매각"
      }
    ]
  }
}
```

Note: fixture has only 2 items for brevity, but `totalCnt` is "12" to test pagination logic.

- [ ] **Step 2: Create fixture for page 2 response (2 items remaining)**

Create `test/fixtures/files/court_auction_criteria_search_page2.json`:

```json
{
  "status": 200,
  "message": "검색 결과가 조회되었습니다.",
  "data": {
    "dma_pageInfo": {
      "pageNo": 2,
      "pageSize": 10,
      "totalYn": "Y",
      "startRowNo": 11,
      "totalCnt": "12",
      "groupTotalCount": 12
    },
    "ipcheck": true,
    "dlt_srchResult": [
      {
        "docid": "B00021120230130200031",
        "srnSaNo": "2023타경20003",
        "boCd": "B000211",
        "saNo": "20230130200031",
        "maemulSer": "1",
        "mokmulSer": "1",
        "printSt": "서울특별시 마포구 상암동 300-3",
        "gamevalAmt": "90000000",
        "minmaePrice": "72000000",
        "yuchalCnt": "3",
        "ipchalGbncd": "000331",
        "maeGiil": "20260425",
        "maegyuljGiil": "20260502",
        "jiwonNm": "서울서부지방법원",
        "dspslUsgNm": "다세대주택",
        "mulJinYn": "Y",
        "mulBigo": ""
      }
    ]
  }
}
```

- [ ] **Step 3: Write the failing test file**

Create `test/adapters/court_auction/criteria_search_client_test.rb`:

```ruby
require "test_helper"

class CourtAuction::CriteriaSearchClientTest < ActiveSupport::TestCase
  ENDPOINT_URL = "https://www.courtauction.go.kr/pgj/pgjsearch/searchControllerMain.on"

  setup do
    @client = CourtAuction::CriteriaSearchClient.new
    @client.define_singleton_method(:sleep) { |_| } # skip sleep in tests
    @page1_response = file_fixture("court_auction_criteria_search_page1.json").read
    @page2_response = file_fixture("court_auction_criteria_search_page2.json").read
    @empty_response = file_fixture("court_auction_empty_search.json").read
  end

  # -- search (single page) ---------------------------------------------------

  test "search returns items and total_count for valid criteria" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @empty_response, headers: { "Content-Type" => "application/json" })

    result = @client.search(region_code: "11", max_price: 150_000_000)

    assert_equal 0, result[:total_count]
    assert_equal [], result[:items]
  end

  test "search sends correct headers" do
    stub = stub_request(:post, ENDPOINT_URL)
      .with(headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "submissionid" => "mf_wfm_mainFrame_sbm_selectGdsDtlSrch",
        "SC-Userid" => "SYSTEM"
      })
      .to_return(status: 200, body: @empty_response, headers: { "Content-Type" => "application/json" })

    @client.search(region_code: "11", max_price: 150_000_000)

    assert_requested stub
  end

  test "search sends correct request body" do
    today = Date.current
    two_weeks = today + 14

    stub = stub_request(:post, ENDPOINT_URL)
      .with { |req|
        body = JSON.parse(req.body)
        params = body["dma_srchGdsDtlSrchInfo"]
        params["rdnmSdCd"] == "11" &&
          params["lwsDspslPrcMin"] == "50000000" &&
          params["lwsDspslPrcMax"] == "150000000" &&
          params["lclDspslGdsLstUsgCd"] == "20000" &&
          params["mclDspslGdsLstUsgCd"] == "20100" &&
          params["sclDspslGdsLstUsgCd"] == "" &&
          params["cortStDvs"] == "3" &&
          params["bidDvsCd"] == "" &&
          params["notifyLoc"] == "on" &&
          params["bidBgngYmd"] == today.strftime("%Y%m%d") &&
          params["bidEndYmd"] == two_weeks.strftime("%Y%m%d") &&
          body["dma_pageInfo"]["pageNo"] == 1 &&
          body["dma_pageInfo"]["pageSize"] == 10 &&
          body["dma_pageInfo"]["totalYn"] == "Y"
      }
      .to_return(status: 200, body: @empty_response, headers: { "Content-Type" => "application/json" })

    @client.search(region_code: "11", max_price: 150_000_000)

    assert_requested stub
  end

  test "search returns items from single-page result" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @page1_response, headers: { "Content-Type" => "application/json" })

    result = @client.search(region_code: "11", max_price: 150_000_000)

    assert_equal 12, result[:total_count]
    assert_equal 2, result[:items].size
    assert_equal "2024타경10001", result[:items].first["srnSaNo"]
  end

  # -- search with pagination --------------------------------------------------

  test "search_all paginates through all pages and merges items" do
    stub_request(:post, ENDPOINT_URL)
      .with { |req| JSON.parse(req.body)["dma_pageInfo"]["pageNo"] == 1 }
      .to_return(status: 200, body: @page1_response, headers: { "Content-Type" => "application/json" })

    stub_request(:post, ENDPOINT_URL)
      .with { |req| JSON.parse(req.body)["dma_pageInfo"]["pageNo"] == 2 }
      .to_return(status: 200, body: @page2_response, headers: { "Content-Type" => "application/json" })

    result = @client.search_all(region_code: "11", max_price: 150_000_000)

    assert_equal 12, result[:total_count]
    assert_equal 3, result[:items].size
    assert_equal "2024타경10001", result[:items][0]["srnSaNo"]
    assert_equal "2024타경10002", result[:items][1]["srnSaNo"]
    assert_equal "2023타경20003", result[:items][2]["srnSaNo"]
  end

  test "search_all returns single page when total fits in one page" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @empty_response, headers: { "Content-Type" => "application/json" })

    result = @client.search_all(region_code: "50", max_price: 100_000_000)

    assert_equal 0, result[:total_count]
    assert_equal [], result[:items]
  end

  # -- region code mapping -----------------------------------------------------

  test "region_code_for extracts region from full address" do
    assert_equal "11", CourtAuction::CriteriaSearchClient.region_code_for("서울특별시 강남구 역삼동 100")
    assert_equal "41", CourtAuction::CriteriaSearchClient.region_code_for("경기도 수원시 팔달구")
    assert_equal "50", CourtAuction::CriteriaSearchClient.region_code_for("제주특별자치도 제주시 애월읍")
  end

  test "region_code_for returns nil for unrecognized address" do
    assert_nil CourtAuction::CriteriaSearchClient.region_code_for("알수없는주소")
    assert_nil CourtAuction::CriteriaSearchClient.region_code_for("")
  end

  # -- next price tier ---------------------------------------------------------

  test "next_price_tier returns first tier strictly greater than amount" do
    assert_equal 100_000_000, CourtAuction::CriteriaSearchClient.next_price_tier(50_000_000)
    assert_equal 100_000_000, CourtAuction::CriteriaSearchClient.next_price_tier(99_999_999)
    assert_equal 150_000_000, CourtAuction::CriteriaSearchClient.next_price_tier(100_000_000)
    assert_equal 1_000_000_000, CourtAuction::CriteriaSearchClient.next_price_tier(950_000_001)
  end

  test "next_price_tier returns max tier for amounts at or above 10억" do
    assert_equal 1_000_000_000, CourtAuction::CriteriaSearchClient.next_price_tier(1_000_000_000)
    assert_equal 1_000_000_000, CourtAuction::CriteriaSearchClient.next_price_tier(2_000_000_000)
  end

  # -- error handling ----------------------------------------------------------

  test "search raises ServiceUnavailableError on HTTP failure" do
    stub_request(:post, ENDPOINT_URL).to_return(status: 500, body: "error")

    assert_raises(DataProvider::ServiceUnavailableError) do
      @client.search(region_code: "11", max_price: 150_000_000)
    end
  end

  test "search raises ConnectionError on network failure" do
    stub_request(:post, ENDPOINT_URL).to_timeout

    assert_raises(DataProvider::ConnectionError) do
      @client.search(region_code: "11", max_price: 150_000_000)
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `bin/rails test test/adapters/court_auction/criteria_search_client_test.rb`
Expected: FAIL — `NameError: uninitialized constant CourtAuction::CriteriaSearchClient`

- [ ] **Step 5: Commit fixtures and test file**

```bash
git add test/fixtures/files/court_auction_criteria_search_page1.json \
        test/fixtures/files/court_auction_criteria_search_page2.json \
        test/adapters/court_auction/criteria_search_client_test.rb
git commit -m "test: add failing tests for CriteriaSearchClient"
```

---

### Task 2: Implement CriteriaSearchClient — make tests pass

**Files:**
- Create: `app/adapters/court_auction/criteria_search_client.rb`

- [ ] **Step 1: Implement the client**

Create `app/adapters/court_auction/criteria_search_client.rb`:

```ruby
module CourtAuction
  class CriteriaSearchClient
    BASE_URL = "https://www.courtauction.go.kr/pgj/"
    ENDPOINT = "pgjsearch/searchControllerMain.on"
    REFERER = "https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ151F00.xml"

    PAGE_SIZE = 10
    TIMEOUT = 30
    MIN_BID_PRICE = "50000000"

    REGION_CODES = {
      "서울특별시" => "11", "부산광역시" => "26", "대구광역시" => "27",
      "인천광역시" => "28", "광주광역시" => "29", "대전광역시" => "30",
      "울산광역시" => "31", "세종특별자치시" => "36", "경기도" => "41",
      "강원도" => "42", "충청북도" => "43", "충청남도" => "44",
      "전라북도" => "45", "전라남도" => "46", "경상북도" => "47",
      "경상남도" => "48", "제주특별자치도" => "50",
      "강원특별자치도" => "51", "전북특별자치도" => "52"
    }.freeze

    PRICE_TIERS = [
      50_000_000, 100_000_000, 150_000_000, 200_000_000, 250_000_000,
      300_000_000, 350_000_000, 400_000_000, 450_000_000, 500_000_000,
      550_000_000, 600_000_000, 650_000_000, 700_000_000, 750_000_000,
      800_000_000, 850_000_000, 900_000_000, 950_000_000, 1_000_000_000
    ].freeze

    def self.region_code_for(address)
      return nil if address.blank?
      REGION_CODES.find { |name, _| address.start_with?(name) }&.last
    end

    def self.next_price_tier(amount)
      PRICE_TIERS.find { |tier| tier > amount } || PRICE_TIERS.last
    end

    def initialize
      @connection = build_connection
    end

    def search(region_code:, max_price:, page: 1)
      response = @connection.post(ENDPOINT, build_request_body(region_code, max_price, page))
      handle_response(response)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise DataProvider::ConnectionError, "Court auction criteria search failed: #{e.message}"
    end

    def search_all(region_code:, max_price:)
      first_page = search(region_code: region_code, max_price: max_price, page: 1)
      all_items = first_page[:items].dup
      total_count = first_page[:total_count]

      total_pages = (total_count.to_f / PAGE_SIZE).ceil
      (2..total_pages).each do |page_no|
        sleep(rand(1.0..2.0))
        page_result = search(region_code: region_code, max_price: max_price, page: page_no)
        all_items.concat(page_result[:items])
      end

      { items: all_items, total_count: total_count }
    end

    private

    def build_connection
      Faraday.new(url: BASE_URL) do |f|
        f.options.timeout = TIMEOUT
        f.options.open_timeout = 10
        f.request :json
        f.response :json
        f.headers["Accept"] = "application/json"
        f.headers["Referer"] = REFERER
        f.headers["submissionid"] = "mf_wfm_mainFrame_sbm_selectGdsDtlSrch"
        f.headers["SC-Userid"] = "SYSTEM"
      end
    end

    def build_request_body(region_code, max_price, page)
      today = Date.current
      two_weeks = today + 14

      {
        "dma_pageInfo" => {
          "pageNo" => page,
          "pageSize" => PAGE_SIZE,
          "totalYn" => "Y"
        },
        "dma_srchGdsDtlSrchInfo" => {
          "mvprpRletDvsCd" => "00031R",
          "cortAuctnSrchCondCd" => "0004601",
          "pgmId" => "PGJ151F01",
          "statNum" => 1,
          "cortStDvs" => "3",
          "csNo" => "",
          "cortOfcCd" => "",
          "bidDvsCd" => "",
          "rdnmSdCd" => region_code,
          "rdnmSggCd" => "",
          "rdnmNo" => "",
          "lclDspslGdsLstUsgCd" => "20000",
          "mclDspslGdsLstUsgCd" => "20100",
          "sclDspslGdsLstUsgCd" => "",
          "lwsDspslPrcMin" => MIN_BID_PRICE,
          "lwsDspslPrcMax" => max_price.to_s,
          "notifyLoc" => "on",
          "bidBgngYmd" => today.strftime("%Y%m%d"),
          "bidEndYmd" => two_weeks.strftime("%Y%m%d")
        }
      }
    end

    def handle_response(response)
      unless response.success?
        raise DataProvider::ServiceUnavailableError,
          "Court auction criteria search failed (#{response.status})"
      end

      body = response.body
      items = body.dig("data", "dlt_srchResult") || []
      total_count = body.dig("data", "dma_pageInfo", "totalCnt").to_i

      { items: items, total_count: total_count }
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they pass**

Run: `bin/rails test test/adapters/court_auction/criteria_search_client_test.rb`
Expected: All PASS

- [ ] **Step 3: Run rubocop**

Run: `bin/rubocop app/adapters/court_auction/criteria_search_client.rb`
Expected: No offenses

- [ ] **Step 4: Commit**

```bash
git add app/adapters/court_auction/criteria_search_client.rb
git commit -m "feat: implement CriteriaSearchClient for HTTP-based criteria search"
```

---

### Task 3: Update adapter layer — redirect search_by_criteria to new client

**Files:**
- Modify: `app/adapters/court_auction_adapter.rb:10`
- Modify: `app/adapters/government_court_auction_adapter.rb:1-7,31-39`

- [ ] **Step 1: Update base adapter interface**

In `app/adapters/court_auction_adapter.rb`, replace:

```ruby
  def search_by_criteria(region:, year:, min_price:, max_price:)
    raise NotImplementedError, "#{self.class}#search_by_criteria must be implemented"
  end
```

with:

```ruby
  def search_by_criteria(region_code:, max_price:)
    raise NotImplementedError, "#{self.class}#search_by_criteria must be implemented"
  end
```

- [ ] **Step 2: Update GovernmentCourtAuctionAdapter**

In `app/adapters/government_court_auction_adapter.rb`, add `@criteria_search_client` to `initialize`:

```ruby
  def initialize
    @browser_client = CourtAuction::BrowserClient.new
    @case_search_client = CourtAuction::CaseSearchClient.new
    @criteria_search_client = CourtAuction::CriteriaSearchClient.new
    @parser = CourtAuction::ResponseParser.new
    @rate_limiter = CourtAuction::RateLimiter.new
  end
```

Replace the `search_by_criteria` method:

```ruby
  def search_by_criteria(region_code:, max_price:)
    @rate_limiter.throttle
    @criteria_search_client.search_all(region_code: region_code, max_price: max_price)
  end
```

- [ ] **Step 3: Run existing adapter tests to check nothing breaks**

Run: `bin/rails test test/adapters/`
Expected: All PASS (existing tests don't call `search_by_criteria` directly on the adapter)

- [ ] **Step 4: Commit**

```bash
git add app/adapters/court_auction_adapter.rb app/adapters/government_court_auction_adapter.rb
git commit -m "refactor: route search_by_criteria through CriteriaSearchClient"
```

---

### Task 4: Update CourtAuctionSearchService — accept address and max_bid_price

**Files:**
- Modify: `app/services/court_auction_search_service.rb`

- [ ] **Step 1: Write failing test for new interface**

Add to `test/services/court_auction_search_service_test.rb` (replace the existing `setup` and add new tests, keeping the persistence/dedup/error tests updated):

Replace the full file with:

```ruby
require "test_helper"

class CourtAuctionSearchServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
  end

  test "creates search_results from adapter response" do
    mock_response = {
      items: [
        {
          "srnSaNo" => "2024타경4812",
          "jiwonNm" => "제주지방법원",
          "printSt" => "제주특별자치도 서귀포시 성산읍",
          "gamevalAmt" => "700374010",
          "minmaePrice" => "240228000",
          "dspslUsgNm" => "기타",
          "mulJinYn" => "Y",
          "yuchalCnt" => "3",
          "maeGiil" => "20260421",
          "mulBigo" => "일괄매각"
        }
      ],
      total_count: 1
    }

    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_args| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    result = CourtAuctionSearchService.call(
      user: @user,
      address: "제주특별자치도 서귀포시 성산읍",
      max_bid_price: 200_000_000
    )

    assert_equal 1, result.count
    assert_nil result.error

    sr = @user.search_results.first
    assert_equal "2024타경4812", sr.case_number
    assert_equal "제주지방법원", sr.court_name
    assert_equal 700_374_010, sr.appraisal_price
    assert_equal 240_228_000, sr.min_bid_price
    assert_equal "진행중", sr.status
    assert_equal 3, sr.failed_bid_count
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "maps address to region_code and max_bid_price to next price tier" do
    mock_response = { items: [], total_count: 0 }
    adapter = Object.new
    captured_args = nil
    adapter.define_singleton_method(:search_by_criteria) do |**args|
      captured_args = args
      mock_response
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(
      user: @user,
      address: "서울특별시 강남구 역삼동 100",
      max_bid_price: 120_000_000
    )

    assert_equal "11", captured_args[:region_code]
    assert_equal 150_000_000, captured_args[:max_price]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "returns error for unrecognized address" do
    result = CourtAuctionSearchService.call(
      user: @user,
      address: "알수없는주소",
      max_bid_price: 100_000_000
    )

    assert_equal 0, result.count
    assert_kind_of ArgumentError, result.error
  end

  test "replaces existing search_results on new search" do
    @user.search_results.create!(case_number: "OLD001", address: "old")

    mock_response = { items: [ { "srnSaNo" => "NEW001", "mulJinYn" => "Y" } ], total_count: 1 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_args| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(
      user: @user,
      address: "제주특별자치도 제주시",
      max_bid_price: 100_000_000
    )

    assert_equal 1, @user.search_results.count
    assert_equal "NEW001", @user.search_results.first.case_number
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "deduplicates multi-property cases and records property_count" do
    mock_response = {
      items: [
        { "srnSaNo" => "2024타경1000", "printSt" => "주소A", "mulJinYn" => "Y" },
        { "srnSaNo" => "2024타경1000", "printSt" => "주소B", "mulJinYn" => "Y" },
        { "srnSaNo" => "2024타경2000", "printSt" => "주소C", "mulJinYn" => "Y" }
      ],
      total_count: 3
    }

    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_args| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(
      user: @user,
      address: "서울특별시 강남구",
      max_bid_price: 300_000_000
    )

    assert_equal 2, @user.search_results.count
    multi = @user.search_results.find_by(case_number: "2024타경1000")
    single = @user.search_results.find_by(case_number: "2024타경2000")
    assert_equal 2, multi.property_count
    assert_equal 1, single.property_count
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "captures DataProvider errors" do
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| raise DataProvider::TimeoutError, "timeout" }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    result = CourtAuctionSearchService.call(
      user: @user,
      address: "서울특별시 강남구",
      max_bid_price: 100_000_000
    )

    assert_equal 0, result.count
    assert_instance_of DataProvider::TimeoutError, result.error
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/court_auction_search_service_test.rb`
Expected: FAIL — wrong number of arguments or missing keyword

- [ ] **Step 3: Update the service implementation**

Replace `app/services/court_auction_search_service.rb` with:

```ruby
class CourtAuctionSearchService
  Result = Data.define(:count, :error)

  def self.call(user:, address:, max_bid_price:)
    new(user: user, address: address, max_bid_price: max_bid_price).call
  end

  def initialize(user:, address:, max_bid_price:)
    @user = user
    @address = address
    @max_bid_price = max_bid_price
  end

  def call
    region_code = CourtAuction::CriteriaSearchClient.region_code_for(@address)
    unless region_code
      return Result.new(count: 0, error: ArgumentError.new("Unknown region in address: #{@address}"))
    end

    max_price = CourtAuction::CriteriaSearchClient.next_price_tier(@max_bid_price)

    adapter = GovernmentCourtAuctionAdapter.new
    response = adapter.search_by_criteria(region_code: region_code, max_price: max_price)

    saved_count = persist_results(response[:items])

    Rails.logger.info(
      "[CourtAuctionSearch] region=#{region_code} max_price=#{max_price} " \
      "total=#{response[:total_count]} saved=#{saved_count}"
    )

    Result.new(count: saved_count, error: nil)
  rescue DataProvider::Error => e
    Result.new(count: 0, error: e)
  end

  private

  def persist_results(items)
    @user.search_results.destroy_all

    deduplicated = deduplicate_by_case_number(items)

    deduplicated.each do |item, property_count|
      @user.search_results.create!(
        case_number: item["srnSaNo"],
        court_name: item["jiwonNm"],
        address: item["printSt"],
        appraisal_price: item["gamevalAmt"].to_i,
        min_bid_price: item["minmaePrice"].to_i,
        property_type: item["dspslUsgNm"],
        status: item["mulJinYn"] == "Y" ? "진행중" : "종결",
        failed_bid_count: item["yuchalCnt"].to_i,
        auction_date: item["maeGiil"],
        remarks: item["mulBigo"],
        property_count: property_count
      )
    end

    deduplicated.size
  end

  def deduplicate_by_case_number(items)
    grouped = items.group_by { |i| i["srnSaNo"] }
    grouped.map { |_, group| [ group.first, group.size ] }
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/court_auction_search_service_test.rb`
Expected: All PASS

- [ ] **Step 5: Run rubocop on changed files**

Run: `bin/rubocop app/services/court_auction_search_service.rb`
Expected: No offenses

- [ ] **Step 6: Commit**

```bash
git add app/services/court_auction_search_service.rb \
        test/services/court_auction_search_service_test.rb
git commit -m "feat: update CourtAuctionSearchService to accept address and max_bid_price"
```

---

### Task 5: Update callers of CourtAuctionSearchService

**Files:**
- Grep for all call sites of `CourtAuctionSearchService.call`
- Expected: `app/controllers/search_results_controller.rb` (or similar)

- [ ] **Step 1: Find and update all callers**

Run: `grep -rn "CourtAuctionSearchService.call" app/`

Update each caller to pass `address:` and `max_bid_price:` from the user's `budget_setting`:

```ruby
# Before:
CourtAuctionSearchService.call(user: current_user)

# After:
bs = current_user.budget_setting
CourtAuctionSearchService.call(
  user: current_user,
  address: bs&.effective_region || BudgetSetting::DEFAULT_REGION,
  max_bid_price: bs&.max_bid_amount.to_i * 10_000
)
```

Note: `budget_setting.effective_region` returns a region name like "서울특별시" which doubles as a valid address prefix. If the caller has a more specific address available, use that instead.

- [ ] **Step 2: Run full test suite**

Run: `bin/rails test`
Expected: All PASS

- [ ] **Step 3: Run rubocop on modified controller**

Run: `bin/rubocop app/controllers/`
Expected: No offenses

- [ ] **Step 4: Commit**

```bash
git add app/controllers/
git commit -m "refactor: update search controller to pass address and max_bid_price"
```

---

### Task 6: Full verification

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All PASS

- [ ] **Step 2: Run rubocop**

Run: `bin/rubocop`
Expected: No offenses

- [ ] **Step 3: Run security audit**

Run: `bin/brakeman --quiet --no-pager`
Expected: No warnings

- [ ] **Step 4: Commit any final fixes if needed**
