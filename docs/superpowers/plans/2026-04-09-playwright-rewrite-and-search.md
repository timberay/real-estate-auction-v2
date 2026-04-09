# Playwright Rewrite & Criteria Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Ferrum with playwright-ruby-client for court auction browser automation, add criteria-based search with per-user parameters, and store search result lists for user selection.

**Architecture:** BrowserClient is rewritten to use Playwright, exposing `fetch_with_detail` (case number → detail) and `search_by_criteria` (params → list). A new `CourtAuctionSearchService` orchestrates criteria searches. Results are stored in `search_results` table, and users import selected items via existing `PropertyDataSyncService`.

**Tech Stack:** Rails 8.1, playwright-ruby-client, Minitest

**Spec:** `docs/superpowers/specs/2026-04-09-playwright-rewrite-and-search-design.md`

---

## File Map

**Create:**
- `db/migrate/TIMESTAMP_add_region_to_budget_settings.rb`
- `db/migrate/TIMESTAMP_create_search_results.rb`
- `app/models/search_result.rb`
- `app/services/court_auction_search_service.rb`
- `app/controllers/search_results_controller.rb`
- `app/views/search_results/index.html.erb`
- `test/models/search_result_test.rb`
- `test/services/court_auction_search_service_test.rb`
- `test/controllers/search_results_controller_test.rb`

**Modify:**
- `Gemfile` — replace ferrum with playwright-ruby-client
- `app/adapters/court_auction/browser_client.rb` — full rewrite to Playwright
- `app/models/budget_setting.rb` — add REGIONS constant, region validation
- `app/models/user.rb` — add `has_many :search_results`
- `config/routes.rb` — add search_results routes
- `test/adapters/court_auction/browser_client_test.rb` — rewrite mocks for Playwright
- `app/errors/data_provider.rb` — no change needed (errors already sufficient)

**Delete:**
- Nothing (Ferrum gem removed from Gemfile but no files deleted)

---

### Task 1: Swap Ferrum for playwright-ruby-client in Gemfile

**Files:**
- Modify: `Gemfile:24`

- [ ] **Step 1: Update Gemfile**

Replace line 24 (`gem "ferrum"`) with:

```ruby
# Browser automation for government site scraping
gem "playwright-ruby-client"
```

- [ ] **Step 2: Bundle install**

```bash
eval "$(rbenv init - zsh)" && bundle install
```

Expected: Bundle completes successfully with playwright-ruby-client installed.

- [ ] **Step 3: Install Playwright browsers**

```bash
eval "$(rbenv init - zsh)" && npx playwright install chromium
```

Expected: Chromium downloaded for Playwright.

- [ ] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore: replace ferrum with playwright-ruby-client"
```

---

### Task 2: Add region to budget_settings + create search_results table

**Files:**
- Create: `db/migrate/TIMESTAMP_add_region_to_budget_settings.rb`
- Create: `db/migrate/TIMESTAMP_create_search_results.rb`
- Create: `app/models/search_result.rb`
- Modify: `app/models/budget_setting.rb`
- Modify: `app/models/user.rb`

- [ ] **Step 1: Generate migrations**

```bash
eval "$(rbenv init - zsh)" && bin/rails generate migration AddRegionToBudgetSettings region:string
eval "$(rbenv init - zsh)" && bin/rails generate migration CreateSearchResults
```

- [ ] **Step 2: Edit the AddRegionToBudgetSettings migration**

Replace the generated migration content with:

```ruby
class AddRegionToBudgetSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :budget_settings, :region, :string, default: "제주특별자치도"
  end
end
```

- [ ] **Step 3: Edit the CreateSearchResults migration**

Replace the generated migration content with:

```ruby
class CreateSearchResults < ActiveRecord::Migration[8.1]
  def change
    create_table :search_results do |t|
      t.references :user, null: false, foreign_key: true
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

    add_index :search_results, [ :user_id, :case_number ], unique: true
  end
end
```

- [ ] **Step 4: Run migrations**

```bash
eval "$(rbenv init - zsh)" && bin/rails db:migrate
```

- [ ] **Step 5: Create SearchResult model**

Create `app/models/search_result.rb`:

```ruby
class SearchResult < ApplicationRecord
  belongs_to :user

  validates :case_number, presence: true, uniqueness: { scope: :user_id }
end
```

- [ ] **Step 6: Add REGIONS and validation to BudgetSetting**

Add to `app/models/budget_setting.rb`, after line 1 (`class BudgetSetting < ApplicationRecord`):

```ruby
  REGIONS = [
    "서울특별시", "부산광역시", "대구광역시", "인천광역시", "광주광역시",
    "대전광역시", "울산광역시", "세종특별자치시", "경기도", "강원도",
    "충청북도", "충청남도", "전라북도", "전라남도", "경상북도",
    "경상남도", "제주특별자치도", "강원특별자치도", "전북특별자치도"
  ].freeze

  DEFAULT_REGION = "제주특별자치도"

  PRICE_OPTIONS = [
    10_000_000, 50_000_000, 100_000_000, 150_000_000,
    200_000_000, 250_000_000, 300_000_000, 350_000_000,
    400_000_000, 450_000_000, 500_000_000, 550_000_000,
    600_000_000, 650_000_000, 700_000_000, 750_000_000,
    800_000_000, 850_000_000, 900_000_000, 950_000_000,
    1_000_000_000
  ].freeze

  DEFAULT_MAX_PRICE = 500_000_000

  validates :region, inclusion: { in: REGIONS }, allow_nil: true
```

Add this instance method before the `private` section (or at end of file before closing `end`):

```ruby
  def max_price_option
    return DEFAULT_MAX_PRICE unless max_bid_amount
    target = max_bid_amount * 10_000
    PRICE_OPTIONS.find { |v| v >= target } || PRICE_OPTIONS.last
  end

  def effective_region
    region.presence || DEFAULT_REGION
  end
```

- [ ] **Step 7: Add search_results association to User**

Add to `app/models/user.rb` after `has_many :api_credentials`:

```ruby
  has_many :search_results, dependent: :destroy
```

- [ ] **Step 8: Run tests to verify nothing broke**

```bash
eval "$(rbenv init - zsh)" && bin/rails test test/models/ -v
```

Expected: All model tests pass.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: add region to budget_settings and create search_results table"
```

---

### Task 3: Rewrite BrowserClient with Playwright

This is the core task — replacing the entire Ferrum-based BrowserClient with Playwright.

**Files:**
- Modify: `app/adapters/court_auction/browser_client.rb` (full rewrite)
- Modify: `test/adapters/court_auction/browser_client_test.rb` (full rewrite)

- [ ] **Step 1: Rewrite BrowserClient**

Replace the full contents of `app/adapters/court_auction/browser_client.rb` with:

```ruby
module CourtAuction
  class BrowserClient
    SEARCH_URL = "https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ151F00.xml"
    API_ENDPOINT = "pgjsearch/searchControllerMain.on"
    DETAIL_API_ENDPOINT = "pgj15B/selectAuctnCsSrchRslt.on"
    DEFAULT_TIMEOUT = ENV.fetch("BROWSER_TIMEOUT", 60).to_i
    PAGE_LOAD_WAIT = 3

    # WebSquare element IDs
    YEAR_SELECT = "mf_wfm_mainFrame_sbx_rletCsYear"
    CASE_NUMBER_INPUT = "mf_wfm_mainFrame_ibx_rletCsNo"
    REGION_RADIO = "mf_wfm_mainFrame_rad_rletSrchBtn_input_2"
    REGION_SELECT = "mf_wfm_mainFrame_sbx_rletAdongSdR"
    USAGE_LARGE_SELECT = "mf_wfm_mainFrame_sbx_rletLclLst"
    USAGE_MID_SELECT = "mf_wfm_mainFrame_sbx_rletMclLst"
    MIN_PRICE_SELECT = "mf_wfm_mainFrame_sbx_rletLwsDspslMin"
    MAX_PRICE_SELECT = "mf_wfm_mainFrame_sbx_rletLwsDspslMax"
    SEARCH_BUTTON = "mf_wfm_mainFrame_btn_gdsDtlSrch"

    def initialize(timeout: DEFAULT_TIMEOUT)
      @timeout = timeout
    end

    def fetch_with_detail(year:, type:, number:)
      with_browser do |page|
        navigate_to_search(page)
        fill_case_number(page, year: year, number: number)
        search_data = click_search_and_capture(page)

        items = search_data.dig("data", "dlt_srchResult") || []
        match = find_matching_item(items, year: year, type: type, number: number)
        raise DataProvider::DataNotFoundError, "Case #{year}#{type}#{number} not found" unless match

        detail_data = click_result_and_capture_detail(page, match)

        { "search" => search_data, "detail" => detail_data }
      end
    end

    def search_by_criteria(region:, year:, min_price:, max_price:)
      with_browser do |page|
        navigate_to_search(page)
        fill_criteria(page, region: region, year: year, min_price: min_price, max_price: max_price)
        search_data = click_search_and_capture(page)

        items = search_data.dig("data", "dlt_srchResult") || []
        total = search_data.dig("data", "dma_pageInfo", "totalCnt").to_i

        { items: items, total: total }
      end
    end

    private

    def with_browser
      playwright = nil
      browser = nil
      begin
        playwright = Playwright.create(playwright_cli_executable_path: find_playwright_cli)
        browser = playwright.chromium.launch(headless: true)
        page = browser.new_page
        yield(page)
      rescue Playwright::TimeoutError => e
        raise DataProvider::TimeoutError, "Court auction browser timeout: #{e.message}"
      rescue JSON::ParserError => e
        raise DataProvider::ParseError, "Invalid JSON from court auction API: #{e.message}"
      ensure
        browser&.close
        playwright&.stop
      end
    end

    def find_playwright_cli
      ENV["PLAYWRIGHT_CLI_PATH"] || "npx playwright"
    end

    def navigate_to_search(page)
      page.goto(SEARCH_URL, wait_until: "networkidle", timeout: @timeout * 1000)
      page.wait_for_timeout(PAGE_LOAD_WAIT * 1000)
    rescue Playwright::Error => e
      raise DataProvider::ServiceUnavailableError, "Court auction site unreachable: #{e.message}"
    end

    def fill_case_number(page, year:, number:)
      set_select_via_js(page, YEAR_SELECT, year.to_s)
      raw_number = number.to_s.gsub(/\A0+/, "")
      page.fill("##{CASE_NUMBER_INPUT}", raw_number)
      page.wait_for_timeout(500)
    end

    def fill_criteria(page, region:, year:, min_price:, max_price:)
      # 1. Click "소재지(새주소)" radio
      page.click("##{REGION_RADIO}")
      page.wait_for_timeout(500)

      # 2. Set region via DOM dispatchEvent (for cascade)
      set_select_via_dom(page, REGION_SELECT, region)
      page.wait_for_timeout(500)

      # 3. Set year
      set_select_via_js(page, YEAR_SELECT, year.to_s)

      # 4. Set usage: 건물 → 주거용건물 (cascade)
      set_select_via_dom(page, USAGE_LARGE_SELECT, "건물")
      page.wait_for_timeout(1500) # wait for mid-category options to load
      set_select_via_dom(page, USAGE_MID_SELECT, "주거용건물")
      page.wait_for_timeout(300)

      # 5. Set price range
      set_select_via_dom(page, MIN_PRICE_SELECT, price_label(50_000_000))
      set_select_via_dom(page, MAX_PRICE_SELECT, price_label(max_price))
      page.wait_for_timeout(300)
    end

    def click_search_and_capture(page)
      response = page.expect_response(
        ->(resp) { resp.url.include?(API_ENDPOINT) && resp.status == 200 },
        timeout: @timeout * 1000
      ) do
        page.evaluate("WebSquare.util.getComponentById('#{SEARCH_BUTTON}').trigger('onclick');")
      end

      JSON.parse(response.body)
    end

    def click_result_and_capture_detail(page, match)
      address = match["printSt"].to_s
      keyword = address.split(/\s+/).find { |w| w.length > 2 } || address[0..10]

      page.wait_for_timeout(1000) # let DOM render

      response = page.expect_response(
        ->(resp) { resp.url.include?(DETAIL_API_ENDPOINT) && resp.status == 200 },
        timeout: @timeout * 1000
      ) do
        page.evaluate(<<~JS)
          (function() {
            var keyword = '#{escape_js(keyword)}';
            var links = document.querySelectorAll('a');
            for (var i = 0; i < links.length; i++) {
              var text = (links[i].textContent || '').trim();
              if (text.indexOf(keyword) >= 0 && text.length > 10) {
                links[i].click();
                return;
              }
            }
          })();
        JS
      end

      JSON.parse(response.body)
    end

    def find_matching_item(items, year:, type:, number:)
      num_str = number.to_s
      candidates = [
        "#{year}#{type}#{num_str}",
        "#{year}#{type}#{num_str.rjust(5, '0')}",
        "#{year}#{type}#{num_str.gsub(/\A0+/, '')}"
      ].uniq
      items.find { |i| candidates.include?(i["srnSaNo"]) }
    end

    def set_select_via_js(page, element_id, value)
      page.evaluate("WebSquare.util.getComponentById('#{element_id}').setValue('#{escape_js(value)}');")
    end

    def set_select_via_dom(page, element_id, value)
      page.evaluate(<<~JS)
        (function() {
          var el = document.getElementById('#{element_id}');
          if (el) {
            el.value = '#{escape_js(value)}';
            el.dispatchEvent(new Event('change', {bubbles: true}));
          }
        })();
      JS
    end

    def price_label(won)
      case won
      when 10_000_000 then "1천만원"
      when 50_000_000 then "5천만원"
      when 1_000_000_000 then "10억원"
      else
        eok = won / 100_000_000
        remainder = (won % 100_000_000) / 10_000_000
        if eok > 0 && remainder > 0
          "#{eok}억#{remainder}천만원"
        elsif eok > 0
          "#{eok}억원"
        else
          "#{won / 10_000_000}천만원"
        end
      end
    end

    def escape_js(str)
      str.to_s.gsub("\\") { "\\\\" }.gsub("'") { "\\'" }
    end
  end
end
```

- [ ] **Step 2: Rewrite BrowserClient tests**

Replace the full contents of `test/adapters/court_auction/browser_client_test.rb` with:

```ruby
require "test_helper"

class CourtAuction::BrowserClientTest < ActiveSupport::TestCase
  setup do
    @client = CourtAuction::BrowserClient.new(timeout: 5)
  end

  # -- price_label ---------------------------------------------------------

  test "price_label for 50_000_000 returns 5천만원" do
    assert_equal "5천만원", @client.send(:price_label, 50_000_000)
  end

  test "price_label for 100_000_000 returns 1억원" do
    assert_equal "1억원", @client.send(:price_label, 100_000_000)
  end

  test "price_label for 150_000_000 returns 1억5천만원" do
    assert_equal "1억5천만원", @client.send(:price_label, 150_000_000)
  end

  test "price_label for 500_000_000 returns 5억원" do
    assert_equal "5억원", @client.send(:price_label, 500_000_000)
  end

  test "price_label for 1_000_000_000 returns 10억원" do
    assert_equal "10억원", @client.send(:price_label, 1_000_000_000)
  end

  test "price_label for 10_000_000 returns 1천만원" do
    assert_equal "1천만원", @client.send(:price_label, 10_000_000)
  end

  # -- find_matching_item --------------------------------------------------

  test "find_matching_item matches exact case number" do
    items = [ { "srnSaNo" => "2024타경6008" } ]
    match = @client.send(:find_matching_item, items, year: "2024", type: "타경", number: "06008")
    assert_equal "2024타경6008", match["srnSaNo"]
  end

  test "find_matching_item matches zero-padded case number" do
    items = [ { "srnSaNo" => "2024타경06008" } ]
    match = @client.send(:find_matching_item, items, year: "2024", type: "타경", number: "6008")
    assert_equal "2024타경06008", match["srnSaNo"]
  end

  test "find_matching_item returns nil when no match" do
    items = [ { "srnSaNo" => "2024타경99999" } ]
    match = @client.send(:find_matching_item, items, year: "2024", type: "타경", number: "6008")
    assert_nil match
  end

  # -- escape_js -----------------------------------------------------------

  test "escape_js escapes single quotes" do
    assert_equal "O\\'Brien", @client.send(:escape_js, "O'Brien")
  end

  test "escape_js escapes backslashes" do
    assert_equal "path\\\\to", @client.send(:escape_js, 'path\\to')
  end
end
```

- [ ] **Step 3: Run tests**

```bash
eval "$(rbenv init - zsh)" && bin/rails test test/adapters/court_auction/browser_client_test.rb -v
```

Expected: All 11 tests pass.

- [ ] **Step 4: Commit**

```bash
git add app/adapters/court_auction/browser_client.rb test/adapters/court_auction/browser_client_test.rb
git commit -m "feat: rewrite BrowserClient with playwright-ruby-client"
```

---

### Task 4: Update GovernmentCourtAuctionAdapter for search_by_criteria

**Files:**
- Modify: `app/adapters/government_court_auction_adapter.rb`
- Modify: `app/adapters/court_auction_adapter.rb`

- [ ] **Step 1: Add search_by_criteria to base adapter**

Replace the full contents of `app/adapters/court_auction_adapter.rb` with:

```ruby
class CourtAuctionAdapter
  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end

  def fetch_data_with_detail(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data_with_detail must be implemented"
  end

  def search_by_criteria(region:, year:, min_price:, max_price:)
    raise NotImplementedError, "#{self.class}#search_by_criteria must be implemented"
  end
end
```

- [ ] **Step 2: Add search_by_criteria to GovernmentCourtAuctionAdapter**

Replace the full contents of `app/adapters/government_court_auction_adapter.rb` with:

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
    api_response = @browser_client.fetch_with_detail(**parsed)

    # Return search-only parse for backward compat
    @parser.parse(api_response: api_response["search"])
  end

  def fetch_data_with_detail(case_number:)
    parsed = CourtAuction::CaseNumberParser.parse(case_number)

    @rate_limiter.throttle
    combined = @browser_client.fetch_with_detail(**parsed)

    @parser.parse_with_detail(
      search_response: combined["search"],
      detail_response: combined["detail"]
    )
  end

  def search_by_criteria(region:, year:, min_price:, max_price:)
    @rate_limiter.throttle
    @browser_client.search_by_criteria(
      region: region,
      year: year,
      min_price: min_price,
      max_price: max_price
    )
  end
end
```

- [ ] **Step 3: Commit**

```bash
git add app/adapters/court_auction_adapter.rb app/adapters/government_court_auction_adapter.rb
git commit -m "feat: add search_by_criteria to court auction adapters"
```

---

### Task 5: Create CourtAuctionSearchService

**Files:**
- Create: `app/services/court_auction_search_service.rb`
- Create: `test/services/court_auction_search_service_test.rb`

- [ ] **Step 1: Write the test**

Create `test/services/court_auction_search_service_test.rb`:

```ruby
require "test_helper"

class CourtAuctionSearchServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @user.create_budget_setting!(
      region: "제주특별자치도",
      max_bid_amount: 30000,
      available_cash: 10000
    ) unless @user.budget_setting
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
      total: 1
    }

    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_args| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    result = CourtAuctionSearchService.call(user: @user)

    assert_equal 1, result.count
    assert_equal 1, @user.search_results.count

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

  test "replaces existing search_results on new search" do
    @user.search_results.create!(case_number: "OLD001", address: "old")

    mock_response = { items: [{ "srnSaNo" => "NEW001", "mulJinYn" => "Y" }], total: 1 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_args| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(user: @user)

    assert_equal 1, @user.search_results.count
    assert_equal "NEW001", @user.search_results.first.case_number
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "uses default region when budget_setting has no region" do
    @user.budget_setting.update!(region: nil)

    mock_response = { items: [], total: 0 }
    adapter = Object.new
    captured_args = nil
    adapter.define_singleton_method(:search_by_criteria) do |**args|
      captured_args = args
      mock_response
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(user: @user)

    assert_equal "제주특별자치도", captured_args[:region]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "uses default max_price when budget_setting has no max_bid_amount" do
    @user.budget_setting.update!(max_bid_amount: nil)

    mock_response = { items: [], total: 0 }
    adapter = Object.new
    captured_args = nil
    adapter.define_singleton_method(:search_by_criteria) do |**args|
      captured_args = args
      mock_response
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    CourtAuctionSearchService.call(user: @user)

    assert_equal 500_000_000, captured_args[:max_price]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "captures DataProvider errors" do
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| raise DataProvider::TimeoutError, "timeout" }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    result = CourtAuctionSearchService.call(user: @user)

    assert_equal 0, result.count
    assert_instance_of DataProvider::TimeoutError, result.error
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
eval "$(rbenv init - zsh)" && bin/rails test test/services/court_auction_search_service_test.rb -v
```

Expected: NameError — `CourtAuctionSearchService` not defined.

- [ ] **Step 3: Implement CourtAuctionSearchService**

Create `app/services/court_auction_search_service.rb`:

```ruby
class CourtAuctionSearchService
  Result = Data.define(:count, :error)

  def self.call(user:)
    new(user:).call
  end

  def initialize(user:)
    @user = user
  end

  def call
    bs = @user.budget_setting

    region = bs&.effective_region || BudgetSetting::DEFAULT_REGION
    year = Time.current.year.to_s
    max_price = bs&.max_price_option || BudgetSetting::DEFAULT_MAX_PRICE

    adapter = GovernmentCourtAuctionAdapter.new
    response = adapter.search_by_criteria(
      region: region,
      year: year,
      min_price: 50_000_000,
      max_price: max_price
    )

    persist_results(response[:items])

    Result.new(count: response[:total], error: nil)
  rescue DataProvider::Error => e
    Result.new(count: 0, error: e)
  end

  private

  def persist_results(items)
    @user.search_results.destroy_all

    items.each do |item|
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
        remarks: item["mulBigo"]
      )
    rescue ActiveRecord::RecordNotUnique
      # Skip duplicate case numbers within same search
      next
    end
  end
end
```

- [ ] **Step 4: Run tests**

```bash
eval "$(rbenv init - zsh)" && bin/rails test test/services/court_auction_search_service_test.rb -v
```

Expected: All 5 tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/court_auction_search_service.rb test/services/court_auction_search_service_test.rb
git commit -m "feat: add CourtAuctionSearchService for criteria-based search"
```

---

### Task 6: Add SearchResultsController + routes

**Files:**
- Create: `app/controllers/search_results_controller.rb`
- Create: `app/views/search_results/index.html.erb`
- Modify: `config/routes.rb`
- Create: `test/controllers/search_results_controller_test.rb`

- [ ] **Step 1: Add routes**

In `config/routes.rb`, add after the `resources :properties` block (after line 43):

```ruby
  resources :search_results, only: [ :index, :create ] do
    member do
      post :import
    end
  end
```

- [ ] **Step 2: Create SearchResultsController**

Create `app/controllers/search_results_controller.rb`:

```ruby
class SearchResultsController < ApplicationController
  def index
    @search_results = current_user.search_results.order(created_at: :desc)
  end

  def create
    result = CourtAuctionSearchService.call(user: current_user)

    if result.error
      redirect_to search_results_path, alert: error_message_for(result.error)
    else
      redirect_to search_results_path, notice: "#{result.count}건의 검색 결과를 가져왔습니다."
    end
  end

  def import
    search_result = current_user.search_results.find(params[:id])
    case_number = search_result.case_number

    property = Property.find_by(case_number: case_number)
    if property
      current_user.user_properties.find_or_create_by!(property: property)
      redirect_to properties_path, notice: "물건이 내 목록에 추가되었습니다."
      return
    end

    result = PropertyDataSyncService.call(case_number: case_number, user: current_user)
    if result.property
      current_user.user_properties.create!(property: result.property)
      redirect_to properties_path, notice: "물건이 추가되었습니다."
    else
      error = result.errors[:court]
      redirect_to search_results_path, alert: error_message_for(error)
    end
  end

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

- [ ] **Step 3: Create a minimal index view**

Create `app/views/search_results/index.html.erb`:

```erb
<div class="space-y-6">
  <div class="flex items-center justify-between">
    <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">경매 물건 검색</h1>
    <%= form_with url: search_results_path, method: :post do %>
      <%= render ButtonComponent.new(type: "submit", icon: "magnifying-glass", size: :sm) { "검색 실행" } %>
    <% end %>
  </div>

  <% if @search_results.any? %>
    <p class="text-sm text-slate-500 dark:text-slate-400"><%= @search_results.count %>건</p>
    <div class="space-y-3">
      <% @search_results.each do |sr| %>
        <div class="rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 p-4">
          <div class="flex items-start justify-between gap-4">
            <div class="flex-1 min-w-0">
              <p class="text-sm font-medium text-slate-900 dark:text-slate-100 truncate"><%= sr.address %></p>
              <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
                <%= sr.case_number %> · <%= sr.court_name %> · <%= sr.property_type %>
              </p>
              <div class="flex gap-4 mt-2 text-sm">
                <span class="text-slate-600 dark:text-slate-300">감정가 <strong class="tabular-nums"><%= number_to_currency(sr.appraisal_price, unit: "", precision: 0) %></strong></span>
                <span class="text-blue-600 dark:text-blue-400">최저가 <strong class="tabular-nums"><%= number_to_currency(sr.min_bid_price, unit: "", precision: 0) %></strong></span>
                <% if sr.failed_bid_count.to_i > 0 %>
                  <span class="text-orange-600 dark:text-orange-400">유찰 <%= sr.failed_bid_count %>회</span>
                <% end %>
              </div>
            </div>
            <%= form_with url: import_search_result_path(sr), method: :post, class: "shrink-0" do %>
              <%= render ButtonComponent.new(type: "submit", icon: "plus", size: :sm, variant: :secondary) { "추가" } %>
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
  <% else %>
    <%= render EmptyStateComponent.new(
      icon: "magnifying-glass",
      title: "검색 결과가 없습니다",
      description: "검색 실행 버튼을 눌러 경매 물건을 검색하세요."
    ) %>
  <% end %>
</div>
```

- [ ] **Step 4: Write controller tests**

Create `test/controllers/search_results_controller_test.rb`:

```ruby
require "test_helper"

class SearchResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url # creates guest session
    @user = User.find_by(email: "guest@auction.local")
  end

  test "GET index shows search results" do
    @user.search_results.create!(
      case_number: "2024타경100",
      address: "제주특별자치도 제주시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )

    get search_results_url
    assert_response :success
    assert_match "제주특별자치도", response.body
  end

  test "GET index shows empty state when no results" do
    get search_results_url
    assert_response :success
    assert_match "검색 결과가 없습니다", response.body
  end

  test "POST create runs search and redirects" do
    mock_response = { items: [], total: 0 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url
    assert_redirected_to search_results_path
    follow_redirect!
    assert_match "0건", flash[:notice]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create shows error on timeout" do
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| raise DataProvider::TimeoutError, "timeout" }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url
    assert_redirected_to search_results_path
    follow_redirect!
    assert_match "시간이 초과", flash[:alert]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST import adds property to user list" do
    sr = @user.search_results.create!(case_number: "2026타경10001", address: "서울")

    # Property already exists in fixtures
    post import_search_result_url(sr)
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "목록에 추가", flash[:notice]
  end
end
```

- [ ] **Step 5: Run tests**

```bash
eval "$(rbenv init - zsh)" && bin/rails test test/controllers/search_results_controller_test.rb -v
```

Expected: All 5 tests pass.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add SearchResultsController with criteria search and import"
```

---

### Task 7: Fix remaining tests and run full suite

**Files:**
- Modify: various test files that may reference Ferrum

- [ ] **Step 1: Run full test suite**

```bash
eval "$(rbenv init - zsh)" && bin/rails test
```

Identify any failures caused by Ferrum references or the Playwright change.

- [ ] **Step 2: Fix each failing test**

Common fixes:
- Replace `Ferrum::TimeoutError` references with `Playwright::TimeoutError` in test error stubs
- Remove `Ferrum::Browser.new` stubs — replace with Playwright stubs
- Update `GovernmentCourtAuctionAdapter` integration test mocks if needed

For the adapter integration test (`test/adapters/government_court_auction_adapter_integration_test.rb`): the mock setup uses `instance_variable_set(:@browser_client, mock_client)`. This still works since BrowserClient is assigned the same way. No changes needed if the mock_client responds to the same methods (`fetch_with_detail`, `search_by_criteria`).

- [ ] **Step 3: Run full test suite again**

```bash
eval "$(rbenv init - zsh)" && bin/rails test
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: fix remaining references for Playwright migration"
```

---

### Task 8: Manual E2E verification

- [ ] **Step 1: Test case number search**

```bash
eval "$(rbenv init - zsh)" && bin/rails runner '
start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
result = PropertyDataSyncService.call(case_number: "2024타경6008")
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
if result.property
  puts "SUCCESS in #{elapsed.round(1)}s: #{result.property.case_number} - #{result.property.address}"
else
  puts "FAILED in #{elapsed.round(1)}s: #{result.errors}"
end
'
```

Expected: Property fetched and saved successfully.

- [ ] **Step 2: Test criteria search**

```bash
eval "$(rbenv init - zsh)" && bin/rails runner '
user = User.find_by(email: "guest@auction.local")
user.budget_setting.update!(region: "제주특별자치도", max_bid_amount: 30000)

start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
result = CourtAuctionSearchService.call(user: user)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
puts "#{result.count}건 in #{elapsed.round(1)}s"
user.search_results.first(3).each { |sr| puts "  #{sr.case_number} #{sr.address}" }
'
```

Expected: Search results fetched and stored.

- [ ] **Step 3: Run full CI**

```bash
eval "$(rbenv init - zsh)" && bin/ci
```

Expected: All checks pass.
