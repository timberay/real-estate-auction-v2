# Case-Number Direct Property Registration with Court Selector — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the case-number direct property registration flow with a required court selector, deliberately cut on 2026-04-11 during MVP scope reduction. Users who already know `{사건번호 + 법원}` from external sources add a property in one form submission via a single ~500ms HTTP call to the court auction site.

**Architecture:** Sequential implementation (no parallelization opportunity per `/plan-eng-review`). Court is **REQUIRED** in the UI — no auto-discovery fallback. PGJ159M00 HTTP API only — no Playwright. `CaseSearchService` swallows `DataProvider::Error` internally and returns a `Result` value carrying the original exception class. A new shared `Concerns::CourtAuctionErrorMessages` is reused by both `PropertiesController` and `SearchResultsController`. Migration adds `court_code/court_name` to `Property` with 1-time backfill from `SearchResult`.

**Tech Stack:** Rails 8.0, Minitest, WebMock, Faraday (HTTP), Tailwind, Stimulus.

**Source documents:**
- Design doc: `~/.gstack/projects/timberay-real-estate-auction-wip/tonny-main-design-20260504-195917.md`
- Test plan: `~/.gstack/projects/timberay-real-estate-auction-wip/tonny-main-eng-review-test-plan-20260504-205358.md`
- Endpoint reference: `docs/superpowers/specs/court-auction-case-search.md`
- Deleted source recovery: `git show 4521efb^:<path>`

**Pre-implementation gate (manual, ~5 minutes):** Before starting Task 1, verify the live PGJ159M00 endpoint still matches the fixture `test/fixtures/files/court_auction_case_search_valid.json`. Run:

```bash
curl -s -X POST 'https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on' \
  -H 'Content-Type: application/json;charset=UTF-8' \
  -H 'submissionid: mf_wfm_mainFrame_sbm_selectCsDtlInf' \
  -H 'sc-userid: NONUSER' \
  -H 'sc-pgmid: PGJ15AF01' \
  -d '{"dma_srchCsDtlInf":{"cortOfcCd":"B000530","csNo":"2022타경564"}}' \
  | jq '.data.dma_csBasInf | {cortOfcCd, cortOfcNm, userCsNo, csProgStatCd}'
```

Expected (matches fixture): `cortOfcCd: "B000530"`, `cortOfcNm: "제주지방법원"`, `userCsNo: "2022타경564"`, `csProgStatCd: "0002100001"`. If response shape differs, STOP and patch field paths in Task 3 before continuing.

---

## File Structure

| File | Action | Lines (est) | Responsibility |
|---|---|---|---|
| `db/migrate/<ts>_add_court_to_properties.rb` | Create | 25 | Add `court_code`, `court_name` columns + 1-time backfill from `search_results` |
| `app/adapters/court_auction/case_number_parser.rb` | Create | 25 | Validate `(\d{4})(타경\|타채)(\d+)` format |
| `app/adapters/court_auction/response_parser.rb` | Modify | +60 | Add `parse_case_search` + helpers (`parse_case_status`, `count_failed_bids`) |
| `app/adapters/court_auction/case_search_client.rb` | Create | 100 | HTTP client for PGJ159M00, `COURT_CODES` constant (60 entries), `court_options_for(user)` ordering helper |
| `app/adapters/government_court_auction_adapter.rb` | Modify | +5 | Add `search_case(court_code:, case_number:)` |
| `app/services/case_search_service.rb` | Create | 50 | `call(court_code:, case_number:)` returning `Result`, internal `RecordNotUnique` rescue |
| `app/controllers/concerns/court_auction_error_messages.rb` | Create | 25 | Shared `error_message_for(error)` case statement |
| `app/controllers/search_results_controller.rb` | Modify | -12 / +6 | Include concern (delete private method); pass `court_code/court_name` in `create_property_from_search_result` |
| `app/controllers/properties_controller.rb` | Modify | -22 / +35 | Rewrite `create` action |
| `app/views/properties/index.html.erb` | Modify | +10 / -1 | Court select before case_number; replace orphan hint copy |
| `test/adapters/court_auction/case_number_parser_test.rb` | Create | 40 | Both 타경/타채, normalization, format error |
| `test/adapters/court_auction/case_search_client_test.rb` | Create | 80 | WebMock: success, malformed, 5xx, timeout, connection error, court_code lookup |
| `test/adapters/court_auction/response_parser_case_search_test.rb` | Create | 60 | Field-by-field PGJ159M00 → Property mapping using fixture |
| `test/services/case_search_service_test.rb` | Create | 100 | Single-court success/not-found/site-error; race; no overwrite |
| `test/controllers/concerns/court_auction_error_messages_test.rb` | Create | 50 | 5 case branches verified independently |
| `test/controllers/properties_controller_test.rb` | Modify | regression | Update lines 24/41/49/56 + add 4 new tests |
| `test/integration/case_number_add_test.rb` | Create | 50 | E2E happy path with WebMock + existing fixture |

---

## Task 1: Migration — Add court_code/court_name to Property

**Files:**
- Create: `db/migrate/<timestamp>_add_court_to_properties.rb`
- Test: schema verification via `bin/rails db:migrate:status`

- [ ] **Step 1: Generate migration skeleton**

```bash
cd /home/tonny/projects/real-estate-auction
bin/rails generate migration AddCourtToProperties court_code:string court_name:string
```

Expected: file created at `db/migrate/<ts>_add_court_to_properties.rb`

- [ ] **Step 2: Replace migration body with backfill version**

Open the generated file. Replace contents with:

```ruby
class AddCourtToProperties < ActiveRecord::Migration[8.0]
  def up
    add_column :properties, :court_code, :string
    add_column :properties, :court_name, :string

    # One-time backfill: properties imported via search_results have
    # court info on the SearchResult row but not on Property. Join by
    # case_number and copy. SearchResult is per-user; pick any row.
    execute <<~SQL
      UPDATE properties
         SET court_code = (
               SELECT court_code FROM search_results
                WHERE search_results.case_number = properties.case_number
                  AND search_results.court_code IS NOT NULL
                LIMIT 1
             ),
             court_name = (
               SELECT court_name FROM search_results
                WHERE search_results.case_number = properties.case_number
                  AND search_results.court_name IS NOT NULL
                LIMIT 1
             )
       WHERE properties.court_code IS NULL
    SQL
  end

  def down
    remove_column :properties, :court_name
    remove_column :properties, :court_code
  end
end
```

- [ ] **Step 3: Run migration**

```bash
bin/rails db:migrate
```

Expected: `== AddCourtToProperties: migrating ===` and `== AddCourtToProperties: migrated`. `db/schema.rb` updated.

- [ ] **Step 4: Verify schema**

```bash
grep "court_code\|court_name" db/schema.rb | head -5
```

Expected: 2 lines under `create_table "properties"` showing both columns.

- [ ] **Step 5: Run migration on test DB**

```bash
bin/rails db:test:prepare
bin/rails test test/models/property_test.rb 2>&1 | tail -5
```

Expected: existing tests pass (no test added yet).

- [ ] **Step 6: Commit (structural only)**

```bash
git add db/migrate/ db/schema.rb
git commit -m "feat: add court_code/court_name columns to properties

Backfills both columns from existing search_results join on
case_number for properties imported via the criteria-search flow."
```

---

## Task 2: CaseNumberParser

**Files:**
- Create: `app/adapters/court_auction/case_number_parser.rb`
- Test: `test/adapters/court_auction/case_number_parser_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/adapters/court_auction/case_number_parser_test.rb`:

```ruby
require "test_helper"

class CourtAuction::CaseNumberParserTest < ActiveSupport::TestCase
  test "parses 타경 case number" do
    result = CourtAuction::CaseNumberParser.parse("2024타경881")
    assert_equal "2024", result[:year]
    assert_equal "타경", result[:type]
    assert_equal "00881", result[:number]
  end

  test "parses 타채 case number (auction by application)" do
    result = CourtAuction::CaseNumberParser.parse("2026타채123")
    assert_equal "2026", result[:year]
    assert_equal "타채", result[:type]
    assert_equal "00123", result[:number]
  end

  test "strips whitespace before matching" do
    result = CourtAuction::CaseNumberParser.parse("  2024 타경 881  ")
    assert_equal "00881", result[:number]
  end

  test "preserves leading zeros via rjust(5)" do
    result = CourtAuction::CaseNumberParser.parse("2024타경7")
    assert_equal "00007", result[:number]
  end

  test "raises ParseError on invalid format" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse("hello")
    end
  end

  test "raises ParseError when 타경/타채 missing" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse("2024-881")
    end
  end

  test "raises ParseError on non-string input" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse(nil)
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bin/rails test test/adapters/court_auction/case_number_parser_test.rb
```

Expected: NameError or LoadError ("uninitialized constant CourtAuction::CaseNumberParser").

- [ ] **Step 3: Write minimal implementation**

Create `app/adapters/court_auction/case_number_parser.rb`:

```ruby
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

- [ ] **Step 4: Run tests to verify pass**

```bash
bin/rails test test/adapters/court_auction/case_number_parser_test.rb
```

Expected: 7 runs, 7 assertions, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/adapters/court_auction/case_number_parser.rb test/adapters/court_auction/case_number_parser_test.rb
git commit -m "feat: add CaseNumberParser for YYYY타경|타채NNNN format"
```

---

## Task 3: ResponseParser — add parse_case_search

**Files:**
- Modify: `app/adapters/court_auction/response_parser.rb`
- Test: `test/adapters/court_auction/response_parser_case_search_test.rb`
- Existing fixture (reuse): `test/fixtures/files/court_auction_case_search_valid.json`

- [ ] **Step 1: Write failing tests**

Create `test/adapters/court_auction/response_parser_case_search_test.rb`:

```ruby
require "test_helper"
require "json"

class CourtAuction::ResponseParserCaseSearchTest < ActiveSupport::TestCase
  setup do
    @parser = CourtAuction::ResponseParser.new
    fixture_path = Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json")
    @api_data = JSON.parse(File.read(fixture_path))["data"]
  end

  test "extracts case_number from userCsNo" do
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal "2022타경564", result[:case_number]
  end

  test "extracts court_code and court_name from dma_csBasInf" do
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal "B000530", result[:court_code]
    assert_equal "제주지방법원", result[:court_name]
  end

  test "extracts case_type from csNm" do
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal "부동산임의경매", result[:case_type]
  end

  test "maps csProgStatCd starting with 0002 to 진행중" do
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal "진행중", result[:status]
  end

  test "maps non-0002 csProgStatCd to 종결" do
    @api_data["dma_csBasInf"]["csProgStatCd"] = "0003100001"
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal "종결", result[:status]
  end

  test "extracts claim_amount as integer" do
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal 260_000_000, result[:claim_amount]
  end

  test "property_count clamps from dlt_dspslGdsDspslObjctLst length" do
    result = @parser.parse_case_search(api_data: @api_data)
    expected = (@api_data["dlt_dspslGdsDspslObjctLst"] || []).length.clamp(1, 99)
    assert_equal expected, result[:property_count]
  end

  test "property_count defaults to 1 when goods list empty" do
    @api_data["dlt_dspslGdsDspslObjctLst"] = []
    result = @parser.parse_case_search(api_data: @api_data)
    assert_equal 1, result[:property_count]
  end

  test "returns nil when dma_csBasInf is missing" do
    @api_data.delete("dma_csBasInf")
    assert_nil @parser.parse_case_search(api_data: @api_data)
  end

  test "returns nil when csNo is blank" do
    @api_data["dma_csBasInf"]["csNo"] = ""
    assert_nil @parser.parse_case_search(api_data: @api_data)
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

```bash
bin/rails test test/adapters/court_auction/response_parser_case_search_test.rb
```

Expected: NoMethodError ("undefined method 'parse_case_search'").

- [ ] **Step 3: Add parse_case_search and helpers to ResponseParser**

Open `app/adapters/court_auction/response_parser.rb`. Just before the final `end` of the class (the file ends with `end\nend` for the class and module), add the new public method. Locate the `private` line if present and insert helpers below it.

Add this method as a public method (insert above the existing `private` keyword, or above `def extract_items` which is private):

```ruby
def parse_case_search(api_data:)
  cs_bas = api_data["dma_csBasInf"]
  return nil if cs_bas.nil? || cs_bas["csNo"].blank?

  goods     = (api_data["dlt_dspslGdsDspslObjctLst"] || []).first || {}
  objects   = (api_data["dlt_rletCsDspslObjctLst"]   || []).first || {}
  demand    = (api_data["dlt_dstrtDemnLstprdDts"]    || []).first || {}
  schedules =  api_data["dlt_rletCsGdsDtsDxdyInf"]   || []

  {
    case_number:             cs_bas["userCsNo"],
    case_type:               cs_bas["csNm"],
    court_code:              cs_bas["cortOfcCd"],
    court_name:              cs_bas["cortOfcNm"],
    claim_amount:            parse_price(cs_bas["clmAmt"]),
    status:                  parse_case_status(cs_bas["csProgStatCd"]),
    property_type:           objects["auctnLstNm"],
    address:                 goods["userSt"],
    sido:                    goods["adongSdNm"],
    sigungu:                 goods["adongSggNm"],
    dong:                    goods["adongEmdNm"],
    building_name:           goods["bldNm"].presence || demand["bldNm"],
    building_detail:         goods["bldDtlDts"],
    appraisal_price:         parse_price(goods["aeeEvlAmt"]),
    min_bid_price:           parse_price(goods["fstPbancLwsDspslPrc"]),
    failed_bid_count:        count_failed_bids(schedules),
    remarks:                 goods["dspslGdsRmk"],
    special_conditions_code: goods["bidDvsCd"],
    property_count:          (api_data["dlt_dspslGdsDspslObjctLst"] || []).length.clamp(1, 99)
  }
end
```

Add these helpers in the `private` section (immediately after the `private` keyword):

```ruby
def parse_case_status(code)
  code&.start_with?("0002") ? "진행중" : "종결"
end

def count_failed_bids(schedules)
  schedules.count { |s| s["auctnDxdyRsltCd"] == "002" }
end
```

- [ ] **Step 4: Run tests to verify pass**

```bash
bin/rails test test/adapters/court_auction/response_parser_case_search_test.rb
```

Expected: 10 runs, all assertions pass.

- [ ] **Step 5: Run full ResponseParser suite to ensure no regression**

```bash
bin/rails test test/adapters/court_auction/response_parser_test.rb
```

Expected: pre-existing tests still pass.

- [ ] **Step 6: Commit**

```bash
git add app/adapters/court_auction/response_parser.rb test/adapters/court_auction/response_parser_case_search_test.rb
git commit -m "feat: add parse_case_search to ResponseParser

Maps PGJ159M00 response to Property attributes including
court_code/court_name (for the new A1 columns) and a clamped
property_count from dlt_dspslGdsDspslObjctLst length."
```

---

## Task 4: CaseSearchClient

**Files:**
- Create: `app/adapters/court_auction/case_search_client.rb`
- Test: `test/adapters/court_auction/case_search_client_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/adapters/court_auction/case_search_client_test.rb`:

```ruby
require "test_helper"

class CourtAuction::CaseSearchClientTest < ActiveSupport::TestCase
  ENDPOINT = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

  setup do
    @client = CourtAuction::CaseSearchClient.new
  end

  test "COURT_CODES has 60 entries" do
    assert_equal 60, CourtAuction::CaseSearchClient::COURT_CODES.size
  end

  test "court_code_for returns code by name" do
    assert_equal "B000530", CourtAuction::CaseSearchClient.court_code_for("제주지방법원")
  end

  test "court_code_for returns nil for unknown name" do
    assert_nil CourtAuction::CaseSearchClient.court_code_for("없는법원")
  end

  test "court_options_for places user-region courts first" do
    options = CourtAuction::CaseSearchClient.court_options_for("제주특별자치도")
    # First optgroup: matching courts
    related = options.find { |group| group.first == "관련 법원" }
    assert related, "should have 관련 법원 optgroup"
    assert_includes related.last.map(&:first), "제주지방법원"
  end

  test "court_options_for returns single optgroup when no region match" do
    options = CourtAuction::CaseSearchClient.court_options_for(nil)
    assert_equal 1, options.size
    assert_equal "전체 법원", options.first.first
  end

  test "search returns body data on 200" do
    fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
    stub_request(:post, ENDPOINT).to_return(status: 200, body: fixture, headers: { "Content-Type" => "application/json" })

    result = @client.search(court_code: "B000530", case_number: "2022타경564")
    assert_equal "B000530", result["dma_csBasInf"]["cortOfcCd"]
  end

  test "search returns nil when dma_csBasInf is missing in 200 response" do
    body = { "data" => { "ipcheck" => true } }.to_json
    stub_request(:post, ENDPOINT).to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

    assert_nil @client.search(court_code: "B000530", case_number: "2099타경999")
  end

  test "search returns nil when csNo is blank in 200 response" do
    body = { "data" => { "dma_csBasInf" => { "csNo" => "" } } }.to_json
    stub_request(:post, ENDPOINT).to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })

    assert_nil @client.search(court_code: "B000530", case_number: "2099타경999")
  end

  test "search raises ServiceUnavailableError on 5xx" do
    stub_request(:post, ENDPOINT).to_return(status: 503, body: "")

    assert_raises(DataProvider::ServiceUnavailableError) do
      @client.search(court_code: "B000530", case_number: "2024타경881")
    end
  end

  test "search raises ConnectionError on Faraday timeout" do
    stub_request(:post, ENDPOINT).to_timeout

    assert_raises(DataProvider::ConnectionError) do
      @client.search(court_code: "B000530", case_number: "2024타경881")
    end
  end

  test "search posts cortOfcCd and csNo in dma_srchCsDtlInf body" do
    fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
    stub_request(:post, ENDPOINT)
      .with(body: hash_including("dma_srchCsDtlInf" => { "cortOfcCd" => "B000530", "csNo" => "2022타경564" }))
      .to_return(status: 200, body: fixture)

    @client.search(court_code: "B000530", case_number: "2022타경564")
    assert_requested :post, ENDPOINT
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

```bash
bin/rails test test/adapters/court_auction/case_search_client_test.rb
```

Expected: NameError ("uninitialized constant CourtAuction::CaseSearchClient").

- [ ] **Step 3: Write CaseSearchClient implementation**

Create `app/adapters/court_auction/case_search_client.rb`:

```ruby
module CourtAuction
  class CaseSearchClient
    BASE_URL = "https://www.courtauction.go.kr/pgj/"
    ENDPOINT = "pgj15A/selectAuctnCsSrchRslt.on"
    REFERER = "https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ159M00.xml"

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    COURT_CODES = {
      "서울중앙지방법원" => "B000210", "서울동부지방법원" => "B000211",
      "서울서부지방법원" => "B000215", "서울남부지방법원" => "B000212",
      "서울북부지방법원" => "B000213", "의정부지방법원" => "B000214",
      "고양지원" => "B214807", "남양주지원" => "B214804",
      "인천지방법원" => "B000240", "부천지원" => "B000241",
      "수원지방법원" => "B000250", "성남지원" => "B000251",
      "여주지원" => "B000252", "평택지원" => "B000253",
      "안산지원" => "B250826", "안양지원" => "B000254",
      "춘천지방법원" => "B000260", "강릉지원" => "B000261",
      "원주지원" => "B000262", "속초지원" => "B000263",
      "영월지원" => "B000264", "청주지방법원" => "B000270",
      "충주지원" => "B000271", "제천지원" => "B000272",
      "영동지원" => "B000273", "대전지방법원" => "B000280",
      "홍성지원" => "B000281", "논산지원" => "B000282",
      "천안지원" => "B000283", "공주지원" => "B000284",
      "서산지원" => "B000285", "대구지방법원" => "B000310",
      "안동지원" => "B000311", "경주지원" => "B000312",
      "김천지원" => "B000313", "상주지원" => "B000314",
      "의성지원" => "B000315", "영덕지원" => "B000316",
      "포항지원" => "B000317", "대구서부지원" => "B000320",
      "부산지방법원" => "B000410", "부산동부지원" => "B000412",
      "부산서부지원" => "B000414", "울산지방법원" => "B000411",
      "창원지방법원" => "B000420", "마산지원" => "B000431",
      "진주지원" => "B000421", "통영지원" => "B000422",
      "밀양지원" => "B000423", "거창지원" => "B000424",
      "광주지방법원" => "B000510", "목포지원" => "B000511",
      "장흥지원" => "B000512", "순천지원" => "B000513",
      "해남지원" => "B000514", "전주지방법원" => "B000520",
      "군산지원" => "B000521", "정읍지원" => "B000522",
      "남원지원" => "B000523", "제주지방법원" => "B000530"
    }.freeze

    # NOTE: must equal exactly 60 entries. If you change this, update tests.

    # Map BudgetSetting region name → city/province courts that belong to it.
    # Used by court_options_for to surface user-relevant courts first.
    REGION_TO_COURTS = {
      "서울특별시"       => %w[서울중앙지방법원 서울동부지방법원 서울서부지방법원 서울남부지방법원 서울북부지방법원],
      "부산광역시"       => %w[부산지방법원 부산동부지원 부산서부지원],
      "대구광역시"       => %w[대구지방법원 대구서부지원],
      "인천광역시"       => %w[인천지방법원 부천지원],
      "광주광역시"       => %w[광주지방법원],
      "대전광역시"       => %w[대전지방법원],
      "울산광역시"       => %w[울산지방법원],
      "세종특별자치시"   => %w[대전지방법원],
      "경기도"           => %w[수원지방법원 성남지원 안산지원 안양지원 의정부지방법원 고양지원 남양주지원 여주지원 평택지원],
      "강원도"           => %w[춘천지방법원 강릉지원 원주지원 속초지원 영월지원],
      "강원특별자치도"   => %w[춘천지방법원 강릉지원 원주지원 속초지원 영월지원],
      "충청북도"         => %w[청주지방법원 충주지원 제천지원 영동지원],
      "충청남도"         => %w[대전지방법원 홍성지원 논산지원 천안지원 공주지원 서산지원],
      "전라북도"         => %w[전주지방법원 군산지원 정읍지원 남원지원],
      "전북특별자치도"   => %w[전주지방법원 군산지원 정읍지원 남원지원],
      "전라남도"         => %w[광주지방법원 목포지원 장흥지원 순천지원 해남지원],
      "경상북도"         => %w[대구지방법원 안동지원 경주지원 김천지원 상주지원 의성지원 영덕지원 포항지원],
      "경상남도"         => %w[창원지방법원 마산지원 진주지원 통영지원 밀양지원 거창지원],
      "제주특별자치도"   => %w[제주지방법원]
    }.freeze

    def self.court_code_for(name)
      COURT_CODES[name]
    end

    # Returns options grouped for grouped_options_for_select.
    # Format: [[group_label, [[label, value], ...]], ...]
    def self.court_options_for(region)
      related_names = REGION_TO_COURTS[region] || []
      related_pairs = related_names.filter_map { |n| [n, COURT_CODES[n]] if COURT_CODES[n] }

      remaining_pairs = COURT_CODES.reject { |n, _| related_names.include?(n) }
                                   .sort_by { |n, _| n }
                                   .map { |n, c| [n, c] }

      groups = []
      groups << ["관련 법원", related_pairs] if related_pairs.any?
      groups << ["전체 법원", remaining_pairs]
      groups
    end

    def initialize
      @connection = build_connection
    end

    def search(court_code:, case_number:)
      response = @connection.post(ENDPOINT, build_request_body(court_code, case_number))
      handle_response(response)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise DataProvider::ConnectionError, "Court auction connection failed: #{e.message}"
    end

    private

    def build_connection
      Faraday.new(url: BASE_URL) do |f|
        f.options.open_timeout = OPEN_TIMEOUT
        f.options.timeout = READ_TIMEOUT
        f.request :json
        f.response :json
        f.headers["Accept"] = "application/json"
        f.headers["Referer"] = REFERER
        f.headers["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
        f.headers["submissionid"] = "mf_wfm_mainFrame_sbm_selectCsDtlInf"
        f.headers["sc-userid"] = "NONUSER"
        f.headers["sc-pgmid"] = "PGJ15AF01"
      end
    end

    def build_request_body(court_code, cs_no)
      { "dma_srchCsDtlInf" => { "cortOfcCd" => court_code, "csNo" => cs_no } }
    end

    def handle_response(response)
      unless response.success?
        raise DataProvider::ServiceUnavailableError,
              "Court auction case search failed (#{response.status})"
      end

      data = response.body["data"]
      return nil if data.nil?

      cs_bas_inf = data["dma_csBasInf"]
      return nil if cs_bas_inf.nil? || cs_bas_inf["csNo"].blank?
      return nil if cs_bas_inf["errMsg"].present?

      data
    end
  end
end
```

- [ ] **Step 4: Run tests to verify pass**

```bash
bin/rails test test/adapters/court_auction/case_search_client_test.rb
```

Expected: 11 runs, all assertions pass.

- [ ] **Step 5: Commit**

```bash
git add app/adapters/court_auction/case_search_client.rb test/adapters/court_auction/case_search_client_test.rb
git commit -m "feat: add CaseSearchClient HTTP adapter for PGJ159M00

Includes COURT_CODES (60 entries), region→court mapping for
the user-region-first select ordering, and 5s open + 10s read
timeouts. Single-court only — no auto-discovery iteration."
```

---

## Task 5: GovernmentCourtAuctionAdapter — search_case

**Files:**
- Modify: `app/adapters/government_court_auction_adapter.rb`
- Test: covered by Task 6's service test (existing project pattern — adapter has no direct test)

- [ ] **Step 1: Read current adapter**

```bash
cat app/adapters/government_court_auction_adapter.rb
```

Confirm it currently has `search_by_criteria` only.

- [ ] **Step 2: Add search_case method**

Open `app/adapters/government_court_auction_adapter.rb`. Inside the class, after the existing `search_by_criteria` method, add:

```ruby
def search_case(court_code:, case_number:)
  @rate_limiter.throttle
  @case_search_client.search(court_code: court_code, case_number: case_number)
end
```

In the `initialize` method, add `@case_search_client = CourtAuction::CaseSearchClient.new` to the list. The full file should look like:

```ruby
class GovernmentCourtAuctionAdapter < CourtAuctionAdapter
  def initialize
    @browser_client = CourtAuction::BrowserClient.new
    @criteria_search_client = CourtAuction::CriteriaSearchClient.new
    @case_search_client = CourtAuction::CaseSearchClient.new
    @parser = CourtAuction::ResponseParser.new
    @rate_limiter = CourtAuction::RateLimiter.new
  end

  def search_by_criteria(region_code:, max_price:, max_items: 100)
    @rate_limiter.throttle
    @criteria_search_client.search_all(region_code: region_code, max_price: max_price, max_items: max_items)
  end

  def search_case(court_code:, case_number:)
    @rate_limiter.throttle
    @case_search_client.search(court_code: court_code, case_number: case_number)
  end
end
```

- [ ] **Step 3: Verify existing tests still pass**

```bash
bin/rails test test/adapters/court_auction/
```

Expected: all pass (no regressions in CriteriaSearchClient or BrowserClient tests).

- [ ] **Step 4: Commit**

```bash
git add app/adapters/government_court_auction_adapter.rb
git commit -m "feat: add search_case to GovernmentCourtAuctionAdapter

Delegates to CaseSearchClient with rate-limit throttle.
Returns raw API data; parsing happens in CaseSearchService."
```

---

## Task 6: CaseSearchService

**Files:**
- Create: `app/services/case_search_service.rb`
- Test: `test/services/case_search_service_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/services/case_search_service_test.rb`:

```ruby
require "test_helper"

class CaseSearchServiceTest < ActiveSupport::TestCase
  ENDPOINT = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

  setup do
    @fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
  end

  test "successful single-court call persists Property and returns Result" do
    stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

    result = nil
    assert_difference "Property.count", 1 do
      result = CaseSearchService.call(court_code: "B000530", case_number: "2022타경564")
    end

    assert result.success?
    assert_equal 1, result.properties.size
    property = result.properties.first
    assert_equal "2022타경564", property.case_number
    assert_equal "B000530", property.court_code
    assert_equal "제주지방법원", property.court_name
  end

  test "returns Result with DataNotFoundError when parser returns nil" do
    body = { "data" => { "dma_csBasInf" => { "csNo" => "" } } }.to_json
    stub_request(:post, ENDPOINT).to_return(status: 200, body: body)

    result = CaseSearchService.call(court_code: "B000530", case_number: "2099타경999")

    refute result.success?
    assert_kind_of DataProvider::DataNotFoundError, result.error
    assert_empty result.properties
  end

  test "returns Result with original DataProvider::Error on site outage" do
    stub_request(:post, ENDPOINT).to_return(status: 503)

    result = CaseSearchService.call(court_code: "B000530", case_number: "2024타경881")

    refute result.success?
    assert_kind_of DataProvider::ServiceUnavailableError, result.error
  end

  test "returns existing Property without overwriting fields" do
    existing = Property.create!(
      case_number: "2022타경564",
      address: "USER-EDITED ADDRESS",
      appraisal_price: 1,
      min_bid_price: 1
    )
    stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)

    assert_no_difference "Property.count" do
      result = CaseSearchService.call(court_code: "B000530", case_number: "2022타경564")
      assert result.success?
      assert_equal existing.id, result.properties.first.id
    end

    existing.reload
    assert_equal "USER-EDITED ADDRESS", existing.address  # NOT overwritten
  end

  test "race condition: simulated RecordNotUnique resolves to existing Property" do
    stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)
    # Simulate concurrent insert: pre-create the row right before persist
    Property.create!(case_number: "2022타경564", appraisal_price: 1, min_bid_price: 1, address: "EXISTING")

    # Force the find_or_create_by! into the rescue branch by stubbing a unique constraint pseudo-violation:
    # Easiest in Minitest is to call twice without resetting WebMock; the second call
    # should not raise.
    result = CaseSearchService.call(court_code: "B000530", case_number: "2022타경564")
    assert result.success?
    assert_equal "EXISTING", result.properties.first.address
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

```bash
bin/rails test test/services/case_search_service_test.rb
```

Expected: NameError ("uninitialized constant CaseSearchService").

- [ ] **Step 3: Write CaseSearchService implementation**

Create `app/services/case_search_service.rb`:

```ruby
class CaseSearchService
  Result = Data.define(:properties, :error) do
    def success? = error.nil?
  end

  def self.call(court_code:, case_number:)
    new.call(court_code: court_code, case_number: case_number)
  end

  def initialize
    @adapter = GovernmentCourtAuctionAdapter.new
    @parser = CourtAuction::ResponseParser.new
  end

  def call(court_code:, case_number:)
    api_data = @adapter.search_case(court_code: court_code, case_number: case_number)
    parsed = api_data && @parser.parse_case_search(api_data: api_data)

    if parsed.nil?
      return Result.new(
        properties: [],
        error: DataProvider::DataNotFoundError.new("Case #{case_number} not found at court #{court_code}")
      )
    end

    property = persist(parsed)
    Result.new(properties: [property], error: nil)
  rescue DataProvider::Error => e
    Rails.logger.error("[CaseSearchService] #{e.class}: #{e.message} (case=#{case_number})")
    Result.new(properties: [], error: e)
  end

  private

  def persist(parsed)
    Property.find_or_create_by!(case_number: parsed[:case_number]) do |p|
      p.assign_attributes(parsed)
    end
  rescue ActiveRecord::RecordNotUnique
    # Concurrent submit raced us. The other writer won; load and return.
    Property.find_by!(case_number: parsed[:case_number])
  end
end
```

- [ ] **Step 4: Run tests to verify pass**

```bash
bin/rails test test/services/case_search_service_test.rb
```

Expected: 5 runs, all assertions pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/case_search_service.rb test/services/case_search_service_test.rb
git commit -m "feat: add CaseSearchService for single-court case lookup

Returns Result(properties:, error:) — swallows DataProvider::Error
internally so it does not collide with ApplicationController
rescue_from. Race condition handled via internal RecordNotUnique
rescue + find_by! fallback. Property fields are first-write-wins."
```

---

## Task 7: CourtAuctionErrorMessages concern

**Files:**
- Create: `app/controllers/concerns/court_auction_error_messages.rb`
- Test: `test/controllers/concerns/court_auction_error_messages_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/controllers/concerns/court_auction_error_messages_test.rb`:

```ruby
require "test_helper"

class CourtAuctionErrorMessagesTest < ActiveSupport::TestCase
  # Use a fresh class that includes the concern so we can call the helper directly
  class Host
    include CourtAuctionErrorMessages
  end

  setup { @host = Host.new }

  test "TimeoutError → 데이터 수집 시간 메시지" do
    msg = @host.send(:error_message_for, DataProvider::TimeoutError.new)
    assert_match "데이터 수집 시간이 초과", msg
  end

  test "ServiceUnavailableError → 사이트 접속 메시지" do
    msg = @host.send(:error_message_for, DataProvider::ServiceUnavailableError.new)
    assert_match "법원경매 사이트에 접속할 수 없습니다", msg
  end

  test "ConnectionError → 사이트 접속 메시지" do
    msg = @host.send(:error_message_for, DataProvider::ConnectionError.new)
    assert_match "법원경매 사이트에 접속할 수 없습니다", msg
  end

  test "ConfigurationError → 시스템 설정 메시지" do
    msg = @host.send(:error_message_for, DataProvider::ConfigurationError.new)
    assert_match "시스템 설정", msg
  end

  test "DataNotFoundError → 찾을 수 없습니다" do
    msg = @host.send(:error_message_for, DataProvider::DataNotFoundError.new)
    assert_match "찾을 수 없습니다", msg
  end

  test "nil → 찾을 수 없습니다" do
    msg = @host.send(:error_message_for, nil)
    assert_match "찾을 수 없습니다", msg
  end

  test "unknown error → 일반 오류" do
    msg = @host.send(:error_message_for, StandardError.new("anything"))
    assert_match "오류가 발생", msg
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

```bash
bin/rails test test/controllers/concerns/court_auction_error_messages_test.rb
```

Expected: NameError ("uninitialized constant CourtAuctionErrorMessages").

- [ ] **Step 3: Create concern**

Create `app/controllers/concerns/court_auction_error_messages.rb`:

```ruby
module CourtAuctionErrorMessages
  extend ActiveSupport::Concern

  private

  def error_message_for(error)
    case error
    when DataProvider::TimeoutError
      "데이터 수집 시간이 초과되었습니다. 다시 시도해주세요."
    when DataProvider::ServiceUnavailableError, DataProvider::ConnectionError
      "법원경매 사이트에 접속할 수 없습니다. 잠시 후 다시 시도해주세요."
    when DataProvider::ConfigurationError
      "브라우저 실행에 실패했습니다. 시스템 설정을 확인해주세요."
    when DataProvider::DataNotFoundError, nil
      "해당 물건을 찾을 수 없습니다."
    else
      "데이터 수집 중 오류가 발생했습니다. 다시 시도해주세요."
    end
  end
end
```

- [ ] **Step 4: Run tests to verify pass**

```bash
bin/rails test test/controllers/concerns/court_auction_error_messages_test.rb
```

Expected: 7 runs, all assertions pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/concerns/court_auction_error_messages.rb test/controllers/concerns/court_auction_error_messages_test.rb
git commit -m "feat: extract CourtAuctionErrorMessages concern

Maps DataProvider exception classes to user-facing Korean
messages. Will be included by both PropertiesController and
SearchResultsController (replaces a private duplicate)."
```

---

## Task 8: Refactor SearchResultsController to use the concern + persist court fields

**Files:**
- Modify: `app/controllers/search_results_controller.rb`
- Test: existing `test/controllers/search_results_controller_test.rb` must still pass

- [ ] **Step 1: Run existing tests for baseline**

```bash
bin/rails test test/controllers/search_results_controller_test.rb 2>&1 | tail -3
```

Note pass count.

- [ ] **Step 2: Edit search_results_controller.rb — include concern, drop private method, persist court fields**

Open `app/controllers/search_results_controller.rb`. Make 3 edits:

**Edit A** — at top of class, add include:

```ruby
class SearchResultsController < ApplicationController
  include ActionView::RecordIdentifier
  include CourtAuctionErrorMessages
```

**Edit B** — in `create_property_from_search_result`, add the two court fields:

```ruby
def create_property_from_search_result(search_result)
  Property.create!(
    case_number: search_result.case_number,
    court_code: search_result.court_code,
    court_name: search_result.court_name,
    address: search_result.address,
    appraisal_price: search_result.appraisal_price,
    min_bid_price: search_result.min_bid_price,
    property_type: search_result.property_type,
    status: search_result.status,
    failed_bid_count: search_result.failed_bid_count,
    property_count: search_result.property_count
  )
end
```

**Edit C** — DELETE the private `error_message_for` method entirely (now provided by the concern). The block to remove starts at the `def error_message_for(error)` line (around line 121) and ends at its closing `end`.

- [ ] **Step 3: Run existing tests to verify no regression**

```bash
bin/rails test test/controllers/search_results_controller_test.rb
```

Expected: same pass count as Step 1.

- [ ] **Step 4: Commit (structural refactor only — no behavior change)**

```bash
git add app/controllers/search_results_controller.rb
git commit -m "refactor: extract error_message_for to concern + persist court fields

- Include CourtAuctionErrorMessages concern (replaces private dup).
- create_property_from_search_result now passes court_code/court_name
  so properties imported via the criteria flow populate the new
  A1 columns."
```

---

## Task 9: PropertiesController#create rewrite + regression test updates

**Files:**
- Modify: `app/controllers/properties_controller.rb`
- Modify: `test/controllers/properties_controller_test.rb`

- [ ] **Step 1: Update existing 3 regression tests + add 4 new ones**

Open `test/controllers/properties_controller_test.rb`. Replace the 3 tests at lines 24, 41, 49, 56 with this block AND add 4 new tests right after them. Net new test set:

```ruby
ENDPOINT = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

test "POST create with court_code + new case fetches from court site and adds to user list" do
  fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
  stub_request(:post, ENDPOINT).to_return(status: 200, body: fixture)

  UserProperty.where(user: @user, property: properties(:safe_apartment)).destroy_all

  assert_difference "Property.count", 1 do
    assert_difference "UserProperty.count", 1 do
      post properties_url, params: { court_code: "B000530", case_number: "2022타경564" }
    end
  end
  property = Property.find_by(case_number: "2022타경564")
  assert_redirected_to property_path(property)
  follow_redirect!
  assert_match "내 목록에 추가했습니다", flash[:notice]
end

test "POST create with already-added case number shows notice" do
  # guest already has safe_apartment via fixture (case_number 2026타경10001)
  fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
  # Adjust fixture's userCsNo so the WebMock returns the safe_apartment case
  body = JSON.parse(fixture)
  body["data"]["dma_csBasInf"]["userCsNo"] = "2026타경10001"
  stub_request(:post, ENDPOINT).to_return(status: 200, body: body.to_json)

  post properties_url, params: { court_code: "B000530", case_number: "2026타경10001" }
  assert_redirected_to property_path(properties(:safe_apartment))
  follow_redirect!
  assert_match "내 목록에 추가했습니다", flash[:notice]
end

test "POST create with blank case number shows format error" do
  post properties_url, params: { court_code: "B000530", case_number: "" }
  assert_redirected_to properties_path
  follow_redirect!
  assert_match "사건번호 형식이 올바르지 않습니다", flash[:alert]
end

test "POST create with case found-not-at-court shows not-found alert" do
  body = { "data" => { "dma_csBasInf" => { "csNo" => "" } } }.to_json
  stub_request(:post, ENDPOINT).to_return(status: 200, body: body)

  post properties_url, params: { court_code: "B000530", case_number: "2099타경999" }
  assert_redirected_to properties_path
  follow_redirect!
  assert_match "물건을 찾을 수 없습니다", flash[:alert]
end

test "POST create with blank court_code shows format error" do
  post properties_url, params: { court_code: "", case_number: "2024타경881" }
  assert_redirected_to properties_path
  follow_redirect!
  assert_match "사건번호 형식이 올바르지 않습니다", flash[:alert]
end

test "POST create with tampered (non-allow-list) court_code shows format error" do
  post properties_url, params: { court_code: "FAKE_CODE", case_number: "2024타경881" }
  assert_redirected_to properties_path
  follow_redirect!
  assert_match "사건번호 형식이 올바르지 않습니다", flash[:alert]
end

test "POST create with bad case_number format shows format error and makes no HTTP call" do
  # No WebMock stub — if HTTP fires, request fails with WebMock::NetConnectNotAllowedError
  post properties_url, params: { court_code: "B000530", case_number: "hello" }
  assert_redirected_to properties_path
  follow_redirect!
  assert_match "사건번호 형식이 올바르지 않습니다", flash[:alert]
end

test "POST create when court site returns 503 shows site-unavailable alert" do
  stub_request(:post, ENDPOINT).to_return(status: 503)

  post properties_url, params: { court_code: "B000530", case_number: "2024타경881" }
  assert_redirected_to properties_path
  follow_redirect!
  assert_match "법원경매 사이트에 접속할 수 없습니다", flash[:alert]
end
```

Make sure `WebMock::API` and `assert_requested` are available in `test_helper.rb`. If `JSON` is not auto-loaded, add `require "json"` to the test file's top (after `require "test_helper"`).

- [ ] **Step 2: Run tests to verify failure**

```bash
bin/rails test test/controllers/properties_controller_test.rb
```

Expected: tests for "court_code" / "사건번호 형식" / "찾을 수 없습니다" all fail because controller still uses old logic.

- [ ] **Step 3: Rewrite PropertiesController#create**

Open `app/controllers/properties_controller.rb`. Make 2 edits:

**Edit A** — at top of class, include the concern:

```ruby
class PropertiesController < ApplicationController
  include CourtAuctionErrorMessages
```

**Edit B** — replace the entire `create` action (currently lines 50-71) with:

```ruby
def create
  case_number = params[:case_number].to_s.strip
  court_code  = params[:court_code].to_s.strip

  unless valid_inputs?(case_number, court_code)
    redirect_to properties_path, alert: "사건번호 형식이 올바르지 않습니다. (예: 2026타경1234)"
    return
  end

  result = CaseSearchService.call(court_code: court_code, case_number: case_number)

  if result.error
    redirect_to properties_path, alert: error_message_for(result.error)
    return
  end

  property = result.properties.first
  current_user.user_properties.find_or_create_by!(property: property)
  redirect_to property_path(property), notice: "내 목록에 추가했습니다."
end
```

Add private helpers at the bottom of the class (above the closing `end`, after any existing `private`):

```ruby
private

def valid_inputs?(case_number, court_code)
  return false if case_number.blank? || court_code.blank?
  return false unless CourtAuction::CaseSearchClient::COURT_CODES.value?(court_code)

  CourtAuction::CaseNumberParser.parse(case_number)
  true
rescue DataProvider::ParseError
  false
end
```

- [ ] **Step 4: Run tests to verify pass**

```bash
bin/rails test test/controllers/properties_controller_test.rb
```

Expected: all 8 listed POST create tests pass; existing GET tests still pass.

- [ ] **Step 5: Run full controller suite for regressions**

```bash
bin/rails test test/controllers/
```

Expected: green.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/properties_controller.rb test/controllers/properties_controller_test.rb
git commit -m "feat: rewrite PropertiesController#create with court_code

- Required court_code + case_number, both top-level params.
- Validates format via CaseNumberParser and court_code allow-list
  before any HTTP call.
- Delegates to CaseSearchService; surfaces user-friendly errors
  via CourtAuctionErrorMessages concern.
- Updates 3 regression tests for new flow; adds 4 new ones
  covering tampered court_code, blank inputs, site outage, and
  case-not-at-this-court."
```

---

## Task 10: View — court select + hint copy

**Files:**
- Modify: `app/views/properties/index.html.erb`

- [ ] **Step 1: Read current properties index view**

```bash
sed -n '50,75p' app/views/properties/index.html.erb
```

Confirm the form_with block at line 52 and the orphan hint at line 72.

- [ ] **Step 2: Replace the case-number form block**

In `app/views/properties/index.html.erb`, replace the block from line 50 ("사건번호로 물건 추가") through line 72 (the hint paragraph) with:

```erb
<label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">사건번호로 물건 추가</label>
<%= form_with url: properties_path, method: :post, class: "space-y-2", data: { action: "submit->criteria-search#submitCaseNumber" } do |f| %>
  <%= select_tag :court_code,
      grouped_options_for_select(CourtAuction::CaseSearchClient.court_options_for(@setting&.effective_region)),
      required: true,
      include_blank: false,
      class: "w-full h-10 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500" %>

  <div class="flex items-center gap-2">
    <%= text_field_tag :case_number, nil,
        placeholder: "예: 2026타경1234",
        required: true,
        data: { criteria_search_target: "caseInput", action: "input->criteria-search#clearCaseError" },
        class: "flex-1 min-w-0 h-10 rounded-md border px-3 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100" %>
    <button type="submit" data-criteria-search-target="addButton"
            class="inline-flex items-center justify-center gap-1.5 w-24 h-10 text-sm font-medium rounded-md bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-400 text-white transition-colors">
      <span data-criteria-search-target="addButtonText" class="flex items-center gap-1">
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.5v15m7.5-7.5h-15"/></svg>
        추가
      </span>
      <svg data-criteria-search-target="addButtonSpinner" class="hidden w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
    </button>
  </div>
<% end %>
<p class="hidden text-sm text-red-500 dark:text-red-400 mt-1" data-criteria-search-target="caseError">사건번호를 입력해주세요</p>
<p class="text-sm text-slate-500 dark:text-slate-400 mt-1.5">법원과 사건번호를 입력해주세요</p>
```

Note: `text_field_tag` (not `f.text_field`) because we're using `select_tag` and `text_field_tag` to keep both as top-level params (`params[:court_code]`, `params[:case_number]`) instead of nesting under a form name.

- [ ] **Step 3: Verify view renders**

Start dev server in background:

```bash
bin/dev &
sleep 5
curl -s http://localhost:3000/properties -b "_session=$(cat tmp/dev_cookie 2>/dev/null)" | grep -c "court_code\|관련 법원"
```

Expected: ≥ 1 match. If 0, check that `@setting` is exposed by the controller (it should be — existing `properties#index` already sets it).

Stop server: `kill %1`.

- [ ] **Step 4: Run full test suite to catch view-related regressions**

```bash
bin/rails test
```

Expected: green.

- [ ] **Step 5: Commit**

```bash
git add app/views/properties/index.html.erb
git commit -m "feat: add required court select to case-number add form

User-region courts surface first via grouped_options_for_select,
all others alphabetical. Hint copy replaced with truthful 법원과
사건번호를 입력해주세요 (no orphan promise)."
```

---

## Task 11: Integration test — E2E happy path

**Files:**
- Create: `test/integration/case_number_add_test.rb`

- [ ] **Step 1: Write integration test**

Create `test/integration/case_number_add_test.rb`:

```ruby
require "test_helper"

class CaseNumberAddTest < ActionDispatch::IntegrationTest
  ENDPOINT = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

  setup do
    sign_in_as(users(:guest))  # adapt to your auth helper
  end

  test "user adds case from external source via court+case form" do
    fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
    stub_request(:post, ENDPOINT).to_return(status: 200, body: fixture)

    # Page renders with court select
    get properties_path
    assert_response :success
    assert_select "select[name=court_code][required]"
    assert_select "input[name=case_number][required]"
    assert_match "법원과 사건번호를 입력해주세요", response.body

    # Submit form
    post properties_path, params: { court_code: "B000530", case_number: "2022타경564" }
    follow_redirect!

    # Property page shows the new property
    assert_response :success
    assert_match "2022타경564", response.body
    assert_match "제주지방법원", response.body
  end

  test "user submitting bad format sees flash without HTTP call" do
    # No stub — WebMock raises if HTTP fires
    post properties_path, params: { court_code: "B000530", case_number: "bad-format" }
    follow_redirect!
    assert_match "사건번호 형식이 올바르지 않습니다", response.body
  end

  private

  # Adapt these to match the project's existing test sign-in pattern.
  # Look in test/test_helper.rb for the existing helper.
  def sign_in_as(user)
    post session_url, params: { email: user.email, password: "password" }
  end
end
```

NOTE: the `sign_in_as` helper signature depends on the project's existing auth pattern. Before submitting, search `test/integration/auth_flow_test.rb` for the actual helper and copy its usage.

- [ ] **Step 2: Adapt sign_in_as to existing pattern**

```bash
grep -n "sign_in\|session_url\|guest" test/integration/auth_flow_test.rb | head -10
grep -rn "def sign_in\|def login_as" test/ | head -5
```

If a helper exists in `test/test_helper.rb`, remove the local `sign_in_as` from this file and use the global helper.

- [ ] **Step 3: Run integration test**

```bash
bin/rails test test/integration/case_number_add_test.rb
```

Expected: 2 runs, all assertions pass.

- [ ] **Step 4: Run full test suite**

```bash
bin/rails test
```

Expected: green.

- [ ] **Step 5: Commit**

```bash
git add test/integration/case_number_add_test.rb
git commit -m "test: add integration test for case-number add E2E happy path

Covers form rendering with required court select, fixture-based
WebMock POST, redirect to property page with court_name visible.
Also covers no-HTTP-on-bad-format guarantee."
```

---

## Final Verification

- [ ] **Step 1: Run full test suite**

```bash
bin/rails test
```

Expected: all green. Note total run/assertion counts.

- [ ] **Step 2: Run rubocop**

```bash
bundle exec rubocop --autocorrect-all
```

Expected: clean. Stage and commit any auto-fixes.

- [ ] **Step 3: Manual smoke test**

```bash
bin/dev
```

In browser:
1. Navigate to `http://localhost:3000/properties`.
2. Verify court select shows "관련 법원" optgroup matching your test user's region first.
3. Pick "제주지방법원", type `2022타경564`, click "+ 추가".
4. Page should redirect to property show with case number, court name, and address visible.
5. Pick same court, type `2099타경999`, click "+ 추가" → flash "해당 물건을 찾을 수 없습니다."
6. Type `bad-format` → flash "사건번호 형식이 올바르지 않습니다."

Stop server.

- [ ] **Step 4: Verify no orphan hint remains**

```bash
grep -r "법원을 선택하면 빠르게" app/ | grep -v ".playwright-mcp"
```

Expected: empty (the orphan hint is fully replaced).

- [ ] **Step 5: Final commit if rubocop autocorrect ran**

```bash
git status
# If anything to add:
git add -A
git commit -m "style: rubocop autocorrect"
```

- [ ] **Step 6: Push to feature branch**

This work was done on a branch (created earlier per gstack convention). Push:

```bash
BRANCH=$(git branch --show-current)
git push -u origin "$BRANCH"
```

Then run `/ship` to create the PR.

---

## Out of Scope (deferred to TODOS.md)

- 60-court auto-discovery fallback when court not selected (would require ActiveJob)
- `Property#refresh_from_court_auction!` for stale-data refresh (uses court_code added by A1)
- Client-side regex validation in Stimulus (skipped — server-side check is sufficient)
- i18n extraction of Korean strings (deferred — hardcoded for MVP)
- Auction schedules + parties tables population from PGJ159M00 response (`auction_schedules` and `parties` keys dropped from parse_case_search return)

## Self-Review Checklist (run before kicking off implementation)

- ✅ Spec coverage: every constraint from design doc's "Eng Review Decisions" maps to a Task. A1 → Task 1+8. A2 → Task 6 (DataNotFoundError wrapping). A3 → Task 4 (5+10s timeouts). Q1 → Tasks 4 + 6 (subset only). Q4 → Task 6 (race in service). T1 → Task 7. T3 → Task 11. P0 #1+#15 → Task 3 (parser extracts court fields) + Task 8 (search_results import populates them) + Task 1 (backfill SQL).
- ✅ No "TBD"/"add appropriate"/"similar to Task N" — every step has actual code or actual command.
- ✅ Type consistency: `CaseSearchService.call(court_code:, case_number:)` keyword args used in all references. `CourtAuction::CaseSearchClient::COURT_CODES.value?` used consistently. `Result.success?`, `Result.properties`, `Result.error` used consistently.
- ✅ Pre-implementation gate (manual curl verification) called out at top before Task 1.
- ✅ Each task ends with a commit. Tidy First respected: Task 1 (migration = structural), Task 8 (refactor + structural in same commit but no behavior change in user-facing flow), Task 9 (behavioral change in dedicated commit).
