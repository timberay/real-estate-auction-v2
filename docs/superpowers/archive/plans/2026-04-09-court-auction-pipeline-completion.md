# Court Auction Pipeline Completion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up the real court auction data collection pipeline so that entering a case number in the UI fetches live data from courtauction.go.kr and stores it in the DB — removing all mock infrastructure.

**Architecture:** Remove mock adapters, CredentialResolver, and multi-provider orchestration. PropertyDataSyncService directly uses GovernmentCourtAuctionAdapter with `fetch_data_with_detail`. PropertiesController handles DataProvider errors with user-friendly Korean messages.

**Tech Stack:** Rails 8.1, Ferrum (Chrome DevTools Protocol), Minitest

**Spec:** `docs/superpowers/specs/2026-04-09-court-auction-pipeline-completion-design.md`

---

## File Map

**Delete:**
- `app/adapters/mock_court_auction_adapter.rb`
- `app/adapters/mock_building_ledger_adapter.rb`
- `app/adapters/mock_registry_transcript_adapter.rb`
- `app/adapters/building_ledger_adapter.rb`
- `app/adapters/government_building_ledger_adapter.rb`
- `app/adapters/registry_transcript_adapter.rb`
- `app/services/credential_resolver.rb`
- `db/seeds/mock_properties.json`
- `test/adapters/mock_court_auction_adapter_test.rb`
- `test/adapters/mock_building_ledger_adapter_test.rb`
- `test/adapters/mock_registry_transcript_adapter_test.rb`
- `test/adapters/court_auction_adapter_test.rb`
- `test/adapters/adapter_factory_test.rb`
- `test/adapters/building_ledger_adapter_test.rb`
- `test/services/credential_resolver_test.rb`
- `test/test_helpers/data_provider_test_helper.rb`
- `test/integration/data_provider_flow_test.rb`

**Modify:**
- `app/adapters/court_auction_adapter.rb` — remove `.for` factory, add `fetch_data_with_detail` interface
- `app/adapters/government_court_auction_adapter.rb` — no changes needed (already correct)
- `app/services/property_data_sync_service.rb` — simplify to court-only, always `fetch_data_with_detail`
- `app/controllers/properties_controller.rb` — add error handling with user-friendly messages
- `.env.example` — remove `USE_MOCK`
- `test/services/property_data_sync_service_test.rb` — rewrite for new simplified service
- `test/controllers/properties_controller_test.rb` — add error scenario tests
- `test/adapters/government_court_auction_adapter_integration_test.rb` — add `fetch_data_with_detail` test

**Create:**
- `test/fixtures/files/court_auction_detail_intercepted.json` — detail API fixture

---

### Task 1: Delete mock infrastructure files

No tests needed — this is a pure removal of dead code.

**Files:**
- Delete: `app/adapters/mock_court_auction_adapter.rb`
- Delete: `app/adapters/mock_building_ledger_adapter.rb`
- Delete: `app/adapters/mock_registry_transcript_adapter.rb`
- Delete: `app/adapters/building_ledger_adapter.rb`
- Delete: `app/adapters/government_building_ledger_adapter.rb`
- Delete: `app/adapters/registry_transcript_adapter.rb`
- Delete: `app/services/credential_resolver.rb`
- Delete: `db/seeds/mock_properties.json`
- Delete: `test/adapters/mock_court_auction_adapter_test.rb`
- Delete: `test/adapters/mock_building_ledger_adapter_test.rb`
- Delete: `test/adapters/mock_registry_transcript_adapter_test.rb`
- Delete: `test/adapters/court_auction_adapter_test.rb`
- Delete: `test/adapters/adapter_factory_test.rb`
- Delete: `test/adapters/building_ledger_adapter_test.rb`
- Delete: `test/services/credential_resolver_test.rb`
- Delete: `test/test_helpers/data_provider_test_helper.rb`
- Delete: `test/integration/data_provider_flow_test.rb`

- [ ] **Step 1: Delete all mock adapter files**

```bash
rm app/adapters/mock_court_auction_adapter.rb
rm app/adapters/mock_building_ledger_adapter.rb
rm app/adapters/mock_registry_transcript_adapter.rb
rm app/adapters/building_ledger_adapter.rb
rm app/adapters/government_building_ledger_adapter.rb
rm app/adapters/registry_transcript_adapter.rb
rm app/services/credential_resolver.rb
rm db/seeds/mock_properties.json
```

- [ ] **Step 2: Delete corresponding test files**

```bash
rm test/adapters/mock_court_auction_adapter_test.rb
rm test/adapters/mock_building_ledger_adapter_test.rb
rm test/adapters/mock_registry_transcript_adapter_test.rb
rm test/adapters/court_auction_adapter_test.rb
rm test/adapters/adapter_factory_test.rb
rm test/adapters/building_ledger_adapter_test.rb
rm test/services/credential_resolver_test.rb
rm test/test_helpers/data_provider_test_helper.rb
rm test/integration/data_provider_flow_test.rb
```

- [ ] **Step 3: Remove USE_MOCK from .env.example**

Replace the full contents of `.env.example` with:

```
RAILS_ENV=development

# Reserve fund defaults are managed in db/seeds/reserve_fund_defaults.json
# To update default values: edit the JSON file and run `bin/rails db:seed`
# Acquisition tax rates by property type:
#   apartment (< 85㎡): 1.1%
#   apartment (>= 136㎡): 3.5%
#   officetel: 4.4%
#   villa: 1.1%
```

- [ ] **Step 4: Verify the app still loads**

```bash
bin/rails runner "puts 'OK'"
```

Expected: `OK` (no load errors). If there are errors, they will point to files that still reference deleted classes — fix those references in subsequent tasks.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove mock adapters, CredentialResolver, and USE_MOCK infrastructure"
```

---

### Task 2: Simplify CourtAuctionAdapter base class

**Files:**
- Modify: `app/adapters/court_auction_adapter.rb`

- [ ] **Step 1: Rewrite CourtAuctionAdapter**

Replace the full contents of `app/adapters/court_auction_adapter.rb` with:

```ruby
class CourtAuctionAdapter
  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end

  def fetch_data_with_detail(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data_with_detail must be implemented"
  end
end
```

- [ ] **Step 2: Verify GovernmentCourtAuctionAdapter still works**

```bash
bin/rails runner "puts GovernmentCourtAuctionAdapter.new.class"
```

Expected: `GovernmentCourtAuctionAdapter`

- [ ] **Step 3: Commit**

```bash
git add app/adapters/court_auction_adapter.rb
git commit -m "refactor: simplify CourtAuctionAdapter to pure interface"
```

---

### Task 3: Create detail API fixture

We need a fixture for the detail API response so integration tests can cover `fetch_data_with_detail` and `parse_with_detail`.

**Files:**
- Create: `test/fixtures/files/court_auction_detail_intercepted.json`

- [ ] **Step 1: Create the detail fixture file**

Create `test/fixtures/files/court_auction_detail_intercepted.json`:

```json
{
  "status": 200,
  "message": "성공",
  "data": {
    "dma_result": {
      "csBaseInfo": {
        "csNm": "부동산임의경매",
        "clmAmt": "350000000"
      },
      "dspslGdsDxdyInfo": {
        "ndstrcRghCtt": "해당사항없음",
        "sprfcExstcDts": null,
        "gdsSpcfcRmk": "본건 아파트는 1층에 위치",
        "tprtyRnkHypthcStngDts": "2024.01.15 근저당 설정",
        "dspslGdsRmk": null,
        "fstPbancLwsDspslPrc": "800000000",
        "scndPbancLwsDspslPrc": "560000000",
        "thrdPbancLwsDspslPrc": "392000000",
        "fothPbancLwsDspslPrc": null
      },
      "gdsDspslObjctLst": [
        {
          "rletDvsDts": "대",
          "bldDtlDts": "101동 1001호",
          "bldNm": "테스트아파트",
          "pjbBuldList": "철근콩크리트조 84.50㎡",
          "dspslStkCtt": null
        }
      ],
      "dstrtDemnInfo": [
        {
          "dstrtDemnLstprdYmd": "20260415"
        }
      ],
      "gdsDspslDxdyLst": [
        {
          "dxdyYmd": "20260501",
          "dxdyHm": "10:00",
          "dxdyPlcNm": "경매법정4별관211호",
          "auctnDxdyKndCd": "매각",
          "auctnDxdyRsltCd": null,
          "tsLwsDspslPrc": "560000000",
          "dspslAmt": null
        },
        {
          "dxdyYmd": "20260301",
          "dxdyHm": "10:00",
          "dxdyPlcNm": "경매법정4별관211호",
          "auctnDxdyKndCd": "매각",
          "auctnDxdyRsltCd": "유찰",
          "tsLwsDspslPrc": "800000000",
          "dspslAmt": null
        }
      ],
      "rgltLandLstAll": [
        [
          {
            "rletDvsDts": "대",
            "landArDts": "45.23",
            "landLdcgDts": "대",
            "rgltRateNmrtVal": "4523",
            "rgltRateDnmnVal": "100000",
            "rletIndctDts": "서울특별시 강남구 역삼동 100-1",
            "rgltLandLtnoAddr": "100-1"
          }
        ]
      ],
      "aeeWevlMnpntLst": [
        {
          "aeeWevlMnpntItmCd": "01",
          "aeeWevlMnpntCtt": "본건은 서울특별시 강남구 역삼동 소재 아파트로서 교통 및 생활편의시설이 양호한 지역에 위치함"
        },
        {
          "aeeWevlMnpntItmCd": "02",
          "aeeWevlMnpntCtt": "건물 상태는 양호하며 특별한 하자는 발견되지 않음"
        }
      ]
    }
  }
}
```

- [ ] **Step 2: Verify fixture is valid JSON**

```bash
ruby -rjson -e "JSON.parse(File.read('test/fixtures/files/court_auction_detail_intercepted.json')); puts 'Valid JSON'"
```

Expected: `Valid JSON`

- [ ] **Step 3: Commit**

```bash
git add test/fixtures/files/court_auction_detail_intercepted.json
git commit -m "test: add court auction detail API fixture"
```

---

### Task 4: Add fetch_data_with_detail integration test

**Files:**
- Modify: `test/adapters/government_court_auction_adapter_integration_test.rb`

- [ ] **Step 1: Write the failing test**

Add to `test/adapters/government_court_auction_adapter_integration_test.rb`, after the existing `setup` block (after line 11), add the detail fixture loading:

Change the setup block to:

```ruby
setup do
  @fixture = JSON.parse(
    File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
  )
  @empty_fixture = JSON.parse(
    File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
  )
  @detail_fixture = JSON.parse(
    File.read(Rails.root.join("test/fixtures/files/court_auction_detail_intercepted.json"))
  )
end
```

Add the following test at the end of the class (before the `private` section):

```ruby
test "fetch_data_with_detail returns merged search + detail data" do
  adapter = build_adapter_with_detail(@fixture, @detail_fixture)
  result = adapter.fetch_data_with_detail(case_number: "2026타경10001")

  # From search
  assert_equal "2026타경10001", result[:case_number]
  assert_equal "아파트", result[:property_type]
  assert_equal 800_000_000, result[:appraisal_price]

  # From detail - csBaseInfo
  assert_equal "부동산임의경매", result[:case_type]
  assert_equal 350_000_000, result[:claim_amount]

  # From detail - dspslGdsDxdyInfo
  assert_nil result[:non_extinguished_rights], "해당사항없음 should be normalized to nil"
  assert_equal "2024.01.15 근저당 설정", result[:senior_mortgage_basis]
  assert_equal 800_000_000, result[:price_round_1]
  assert_equal 560_000_000, result[:price_round_2]

  # Auction schedules
  assert_equal 2, result[:auction_schedules].length
  first_schedule = result[:auction_schedules].first
  assert_equal Date.new(2026, 5, 1), first_schedule[:schedule_date]
  assert_equal "10:00", first_schedule[:schedule_time]

  # Land details
  assert_equal 1, result[:land_details].length
  assert_equal "대", result[:land_details].first[:land_type]

  # Appraisal points
  assert_equal 2, result[:appraisal_points].length
  assert_equal "01", result[:appraisal_points].first[:item_code]
end

test "fetch_data_with_detail returns nil when case not found" do
  adapter = build_adapter_with_detail(@empty_fixture, nil)
  result = adapter.fetch_data_with_detail(case_number: "2026타경99999")

  assert_nil result
end
```

Add this helper in the `private` section:

```ruby
def build_adapter_with_detail(search_response, detail_response)
  adapter = GovernmentCourtAuctionAdapter.new

  mock_client = Object.new
  mock_client.define_singleton_method(:fetch) { |**_args| search_response }
  mock_client.define_singleton_method(:fetch_with_detail) do |**_args|
    { "search" => search_response, "detail" => detail_response }
  end

  adapter.instance_variable_set(:@browser_client, mock_client)
  adapter.instance_variable_set(
    :@rate_limiter,
    CourtAuction::RateLimiter.new(min_interval: 0, max_per_minute: 1000)
  )

  adapter
end
```

- [ ] **Step 2: Run the test to verify it passes**

```bash
bin/rails test test/adapters/government_court_auction_adapter_integration_test.rb -v
```

Expected: All tests pass (the adapter code already supports `fetch_data_with_detail`).

- [ ] **Step 3: Commit**

```bash
git add test/adapters/government_court_auction_adapter_integration_test.rb
git commit -m "test: add fetch_data_with_detail integration tests"
```

---

### Task 5: Simplify PropertyDataSyncService

**Files:**
- Modify: `app/services/property_data_sync_service.rb`
- Modify: `test/services/property_data_sync_service_test.rb`

- [ ] **Step 1: Write the failing tests first**

Replace the full contents of `test/services/property_data_sync_service_test.rb` with:

```ruby
require "test_helper"

class PropertyDataSyncServiceTest < ActiveSupport::TestCase
  setup do
    @search_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
    )
    @detail_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_detail_intercepted.json"))
    )
  end

  test "creates new property with court data" do
    stub_adapter(@search_fixture, @detail_fixture)

    Property.where(case_number: "2026타경10001").destroy_all
    assert_difference "Property.count", 1 do
      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      property = result.property

      assert_equal "2026타경10001", property.case_number
      assert_equal "아파트", property.property_type
      assert_equal "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호", property.address
      assert_equal 800_000_000, property.appraisal_price
      assert_equal 560_000_000, property.min_bid_price
    end
  end

  test "creates sale_detail from detail data" do
    stub_adapter(@search_fixture, @detail_fixture)
    Property.where(case_number: "2026타경10001").destroy_all

    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    detail = result.property.sale_detail

    assert_not_nil detail
    assert_equal "부동산임의경매", result.property.case_type
    assert_equal "2024.01.15 근저당 설정", detail.senior_mortgage_basis
    assert_equal 800_000_000, detail.price_round_1
    assert_equal 560_000_000, detail.price_round_2
  end

  test "creates auction_schedules from detail data" do
    stub_adapter(@search_fixture, @detail_fixture)
    Property.where(case_number: "2026타경10001").destroy_all

    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    schedules = result.property.auction_schedules

    assert_equal 2, schedules.count
    assert_equal Date.new(2026, 5, 1), schedules.order(:schedule_date).last.schedule_date
  end

  test "creates land_details from detail data" do
    stub_adapter(@search_fixture, @detail_fixture)
    Property.where(case_number: "2026타경10001").destroy_all

    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    lands = result.property.land_details

    assert_equal 1, lands.count
    assert_equal "대", lands.first.land_type
  end

  test "creates appraisal_points from detail data" do
    stub_adapter(@search_fixture, @detail_fixture)
    Property.where(case_number: "2026타경10001").destroy_all

    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    points = result.property.appraisal_points

    assert_equal 2, points.count
    assert_equal "01", points.first.item_code
  end

  test "upserts existing property without duplicating" do
    stub_adapter(@search_fixture, @detail_fixture)
    Property.where(case_number: "2026타경10001").destroy_all

    PropertyDataSyncService.call(case_number: "2026타경10001")
    assert_no_difference "Property.count" do
      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_equal "2026타경10001", result.property.case_number
    end
  end

  test "returns Result with court_data, errors, property" do
    stub_adapter(@search_fixture, @detail_fixture)
    Property.where(case_number: "2026타경10001").destroy_all

    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    assert_respond_to result, :court_data
    assert_respond_to result, :errors
    assert_respond_to result, :property
  end

  test "returns nil property when case not found" do
    empty_search = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
    stub_adapter(empty_search, nil)

    result = PropertyDataSyncService.call(case_number: "2026타경99999")
    assert_nil result.property
    assert_nil result.court_data
  end

  test "captures DataProvider errors in result.errors" do
    GovernmentCourtAuctionAdapter.stub(:new, ->() {
      adapter = Object.new
      adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
        raise DataProvider::TimeoutError, "timed out"
      end
      adapter
    }) do
      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_nil result.property
      assert result.errors.key?(:court)
      assert_instance_of DataProvider::TimeoutError, result.errors[:court]
    end
  end

  test "accepts user parameter" do
    stub_adapter(@search_fixture, @detail_fixture)
    Property.where(case_number: "2026타경10001").destroy_all

    user = users(:guest)
    result = PropertyDataSyncService.call(case_number: "2026타경10001", user: user)
    assert result.court_data.present?
    assert result.property.present?
  end

  private

  def stub_adapter(search_response, detail_response)
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_with_detail) do |**_args|
      { "search" => search_response, "detail" => detail_response }
    end

    adapter = GovernmentCourtAuctionAdapter.allocate
    adapter.instance_variable_set(:@browser_client, mock_client)
    adapter.instance_variable_set(:@parser, CourtAuction::ResponseParser.new)
    adapter.instance_variable_set(:@rate_limiter,
      CourtAuction::RateLimiter.new(min_interval: 0, max_per_minute: 1000))

    GovernmentCourtAuctionAdapter.stub(:new, adapter) do
      yield if block_given?
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/services/property_data_sync_service_test.rb -v
```

Expected: Failures because PropertyDataSyncService still references CredentialResolver, BuildingLedgerAdapter, etc.

- [ ] **Step 3: Rewrite PropertyDataSyncService**

Replace the full contents of `app/services/property_data_sync_service.rb` with:

```ruby
class PropertyDataSyncService
  Result = Data.define(:court_data, :errors, :property)

  def self.call(case_number:, user: nil)
    new(case_number:).call
  end

  def initialize(case_number:)
    @case_number = case_number
  end

  def call
    errors = {}
    court_data = nil

    begin
      adapter = GovernmentCourtAuctionAdapter.new
      court_data = adapter.fetch_data_with_detail(case_number: @case_number)
    rescue DataProvider::Error => e
      errors[:court] = e
    end

    property = persist_property(court_data) if court_data

    Result.new(court_data: court_data, errors: errors, property: property)
  end

  private

  def persist_property(court_data)
    property = Property.find_or_initialize_by(case_number: @case_number)

    property.assign_attributes(
      property_type: court_data[:property_type],
      property_usage_code: court_data[:property_usage_code],
      status: court_data[:status],
      address: court_data[:address],
      sido: court_data[:sido],
      sigungu: court_data[:sigungu],
      dong: court_data[:dong],
      building_name: court_data[:building_name],
      building_detail: court_data[:building_detail],
      building_structure: court_data[:building_structure],
      exclusive_area: court_data[:exclusive_area],
      appraisal_price: court_data[:appraisal_price],
      min_bid_price: court_data[:min_bid_price],
      failed_bid_count: court_data[:failed_bid_count],
      view_count: court_data[:view_count],
      interest_count: court_data[:interest_count],
      latitude: court_data[:latitude],
      longitude: court_data[:longitude],
      special_conditions_code: court_data[:special_conditions_code],
      remarks: court_data[:remarks],
      case_type: court_data[:case_type],
      claim_amount: court_data[:claim_amount],
      land_category: court_data[:land_category]
    )
    property.save!

    sync_sale_detail(property, court_data)
    sync_auction_schedules(property, court_data[:auction_schedules])
    sync_land_details(property, court_data[:land_details])
    sync_appraisal_points(property, court_data[:appraisal_points])

    property
  end

  SALE_DETAIL_KEYS = %i[
    non_extinguished_rights superficies_details specification_remarks
    senior_mortgage_basis goods_remarks dividend_demand_deadline
    share_description price_round_1 price_round_2 price_round_3 price_round_4
  ].freeze

  def sync_sale_detail(property, court_data)
    detail_attrs = court_data.slice(*SALE_DETAIL_KEYS)
    return if detail_attrs.values.all?(&:blank?)

    detail = property.sale_detail || property.build_sale_detail
    detail.update!(detail_attrs)
  end

  def sync_auction_schedules(property, schedules)
    return if schedules.blank?

    property.auction_schedules.destroy_all
    schedules.each { |attrs| property.auction_schedules.create!(attrs) }
  end

  def sync_land_details(property, lands)
    return if lands.blank?

    property.land_details.destroy_all
    lands.each { |attrs| property.land_details.create!(attrs) }
  end

  def sync_appraisal_points(property, points)
    return if points.blank?

    property.appraisal_points.destroy_all
    points.each { |attrs| property.appraisal_points.create!(attrs) }
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/services/property_data_sync_service_test.rb -v
```

Expected: All 9 tests pass.

Note: The `stub_adapter` helper uses Minitest's built-in `stub` method on `GovernmentCourtAuctionAdapter.new` to return a pre-configured adapter with a mock BrowserClient. The real browser is never launched during tests.

- [ ] **Step 5: Commit**

```bash
git add app/services/property_data_sync_service.rb test/services/property_data_sync_service_test.rb
git commit -m "feat: simplify PropertyDataSyncService to court-auction only with fetch_data_with_detail"
```

---

### Task 6: Add error handling to PropertiesController

**Files:**
- Modify: `app/controllers/properties_controller.rb`
- Modify: `test/controllers/properties_controller_test.rb`

- [ ] **Step 1: Write failing tests for error scenarios**

Add the following tests to `test/controllers/properties_controller_test.rb` (before the final `end`):

```ruby
test "POST create with invalid case number format shows format error" do
  post properties_url, params: { case_number: "invalid-format" }
  assert_redirected_to properties_path
  follow_redirect!
  assert_match "사건번호 형식이 올바르지 않습니다", flash[:alert]
end

test "POST create handles timeout error" do
  GovernmentCourtAuctionAdapter.stub(:new, ->() {
    adapter = Object.new
    adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
      raise DataProvider::TimeoutError, "timed out"
    end
    adapter
  }) do
    post properties_url, params: { case_number: "2026타경88888" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "시간이 초과", flash[:alert]
  end
end

test "POST create handles service unavailable error" do
  GovernmentCourtAuctionAdapter.stub(:new, ->() {
    adapter = Object.new
    adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
      raise DataProvider::ServiceUnavailableError, "site down"
    end
    adapter
  }) do
    post properties_url, params: { case_number: "2026타경88888" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "접속할 수 없습니다", flash[:alert]
  end
end

test "POST create handles configuration error" do
  GovernmentCourtAuctionAdapter.stub(:new, ->() {
    adapter = Object.new
    adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
      raise DataProvider::ConfigurationError, "no chromium"
    end
    adapter
  }) do
    post properties_url, params: { case_number: "2026타경88888" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "시스템 설정을 확인", flash[:alert]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
bin/rails test test/controllers/properties_controller_test.rb -v
```

Expected: New error-handling tests fail because the controller doesn't rescue these errors yet.

- [ ] **Step 3: Update PropertiesController with error handling**

Replace the full contents of `app/controllers/properties_controller.rb` with:

```ruby
class PropertiesController < ApplicationController
  def index
    @user_properties = current_user.user_properties
      .includes(:property)
      .order(created_at: :desc)
    @user_properties = @user_properties.where(safety_rating: params[:safety_rating]) if params[:safety_rating].present?
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @user_properties = @user_properties.joins(:property).where(
        "properties.case_number LIKE :q OR properties.address LIKE :q OR properties.building_name LIKE :q",
        q: search_term
      )
    end
    @max_bid_amount = current_user.budget_setting&.max_bid_amount
    if params[:within_budget] == "1" && @max_bid_amount.present?
      @user_properties = @user_properties.joins(:property).where("properties.appraisal_price <= ?", @max_bid_amount * 10000)
    end
  end

  def show
    @property = Property.find(params[:id])
    @user_property = current_user.user_properties.find_by(property: @property)

    if @user_property&.safety_rating.present?
      redirect_to property_inspections_grade_path(@property)
    elsif @user_property&.analyzed_at.present?
      redirect_to edit_property_inspections_tab_path(@property, tab_key: "rights_analysis")
    end
  end

  def create
    case_number = params[:case_number]&.strip

    if case_number.blank?
      redirect_to properties_path, alert: "사건번호를 입력해주세요."
      return
    end

    property = Property.find_by(case_number: case_number)

    if property
      if current_user.user_properties.exists?(property: property)
        redirect_to properties_path, notice: "이미 내 목록에 있는 물건입니다."
      else
        current_user.user_properties.create!(property: property)
        redirect_to properties_path, notice: "이미 등록된 물건입니다. 내 목록에 추가했습니다."
      end
    else
      result = PropertyDataSyncService.call(case_number: case_number, user: current_user)
      if result.property
        current_user.user_properties.create!(property: result.property)
        redirect_to properties_path, notice: "물건이 추가되었습니다."
      else
        error = result.errors[:court]
        redirect_to properties_path, alert: error_message_for(error)
      end
    end
  rescue DataProvider::ParseError => e
    if e.message.include?("Invalid case number format")
      redirect_to properties_path, alert: "사건번호 형식이 올바르지 않습니다. (예: 2026타경1234)"
    else
      redirect_to properties_path, alert: "데이터 처리 중 오류가 발생했습니다."
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
      "해당 사건번호의 물건을 찾을 수 없습니다."
    else
      "데이터 수집 중 오류가 발생했습니다. 다시 시도해주세요."
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
bin/rails test test/controllers/properties_controller_test.rb -v
```

Expected: All tests pass (existing + new error-handling tests).

Note: The `ParseError` for invalid case number format is raised by `CaseNumberParser.parse` which is called inside `GovernmentCourtAuctionAdapter#fetch_data_with_detail`. Since `PropertyDataSyncService` catches `DataProvider::Error` and stores it in `errors[:court]`, the `ParseError` for invalid format will be caught there. However, the `CaseNumberParser` raises before any network call, so it's efficient. The controller also has a top-level `rescue` for `ParseError` that checks the message — this catches the case where the error propagates before entering the service (e.g., if the service implementation changes).

- [ ] **Step 5: Commit**

```bash
git add app/controllers/properties_controller.rb test/controllers/properties_controller_test.rb
git commit -m "feat: add error-specific user messages in PropertiesController"
```

---

### Task 7: Update existing tests that reference removed code

Some existing tests may reference `CredentialResolver`, mock adapters, or `USE_MOCK`. Fix any remaining references.

**Files:**
- Modify: Any remaining test files that fail

- [ ] **Step 1: Run the full test suite**

```bash
bin/rails test 2>&1 | head -100
```

Identify any failures caused by references to deleted files/classes.

- [ ] **Step 2: Fix each failing test**

Common fixes:
- Remove `require "test_helpers/data_provider_test_helper"` lines
- Remove `include DataProviderTestHelper` lines
- Remove tests that test mock adapter behavior
- Update any test that calls `PropertyDataSyncService.call` to stub the adapter (use the pattern from Task 5)

For each file, check if it references:
- `MockCourtAuctionAdapter` → remove test or update
- `CredentialResolver` → remove test
- `USE_MOCK` → remove env manipulation
- `BuildingLedgerAdapter` → remove test
- `RegistryTranscriptAdapter` → remove test
- `result.building_data` or `result.registry_data` → update to new Result shape

- [ ] **Step 3: Run full test suite again**

```bash
bin/rails test
```

Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "test: fix remaining test references to removed mock infrastructure"
```

---

### Task 8: Verify end-to-end with manual test

This task verifies the full pipeline works against the real courtauction.go.kr site.

- [ ] **Step 1: Ensure Chromium is available**

```bash
which chromium-browser || which chromium || which google-chrome
```

If none found, install or set `BROWSER_PATH` in `.env`.

- [ ] **Step 2: Reset and seed the database**

```bash
bin/rails db:reset
```

Expected: Seeds run without errors. The seed file only uses `real_properties.json`, no mock data.

- [ ] **Step 3: Start the dev server and test manually**

```bash
bin/dev
```

1. Open `http://localhost:3000/properties`
2. Enter a real case number (e.g., one from `db/seeds/real_properties.json`)
3. Click "추가"
4. Verify: property appears in the list with correct data
5. Click the property to verify detail data (auction schedules, etc.)

- [ ] **Step 4: Test error scenarios manually**

1. Enter an invalid case number (e.g., "abc123") — expect format error message
2. Enter a non-existent case number (e.g., "2099타경99999") — expect "찾을 수 없습니다" message

- [ ] **Step 5: Run full CI pipeline**

```bash
bin/ci
```

Expected: All checks pass (rubocop, security audits, tests, seed check).
