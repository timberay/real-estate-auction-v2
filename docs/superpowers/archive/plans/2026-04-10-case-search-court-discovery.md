# Case Search Court Auto-Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable case number search to automatically discover which court holds a case by iterating through all 60 courts via HTTP API, then fetch full details via the existing PropertyDataSyncService.

**Architecture:** Add `find_by_case_number` class method to `CaseSearchService` that iterates courts in priority order with adaptive rate limiting. `PropertiesController#create` switches from direct `PropertyDataSyncService` call to discovery-first flow: find court → sync details.

**Tech Stack:** Ruby on Rails, Minitest, WebMock, Faraday (HTTP client)

**Spec:** `docs/superpowers/specs/2026-04-10-case-search-court-discovery-design.md`

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `app/adapters/court_auction/case_search_client.rb` | Add `PRIORITY_COURT_CODES` ordered list |
| Modify | `app/services/case_search_service.rb` | Add `find_by_case_number` with court iteration + adaptive rate limiting |
| Modify | `app/controllers/properties_controller.rb` | Use discovery-first flow in `create` |
| Modify | `test/services/case_search_service_test.rb` | Tests for court discovery |
| Modify | `test/controllers/properties_controller_test.rb` | Update controller tests for new flow |

---

### Task 1: Add Priority Court Order to CaseSearchClient

**Files:**
- Modify: `app/adapters/court_auction/case_search_client.rb`
- Test: `test/adapters/court_auction/case_search_client_test.rb`

- [ ] **Step 1: Write failing test for priority court codes**

Add to `test/adapters/court_auction/case_search_client_test.rb`:

```ruby
test "priority_court_codes returns all courts with priority ones first" do
  codes = CourtAuction::CaseSearchClient.priority_court_codes

  # Contains all 60 courts
  assert_equal CourtAuction::CaseSearchClient::COURT_CODES.size, codes.size

  # Seoul courts come first
  first_5 = codes.first(5).map(&:first)
  assert_includes first_5, "서울중앙지방법원"
  assert_includes first_5, "서울동부지방법원"
  assert_includes first_5, "서울서부지방법��"
  assert_includes first_5, "서울남부지방법원"
  assert_includes first_5, "서울북부지방법원"

  # Gyeonggi courts come next
  next_batch = codes.slice(5, 7).map(&:first)
  assert_includes next_batch, "수원지방법원"
  assert_includes next_batch, "의정부지방법원"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/adapters/court_auction/case_search_client_test.rb -v`
Expected: FAIL — `NoMethodError: undefined method 'priority_court_codes'`

- [ ] **Step 3: Implement priority_court_codes**

Add to `app/adapters/court_auction/case_search_client.rb` inside the class body, after `COURT_CODES`:

```ruby
PRIORITY_COURTS = %w[
  서울중앙���방법원 서울동부지��법원 서울서��지방법원 서울남부지방법원 서울북���지방법원
  수원지방법�� 성남지원 안산지원 안양지원 의정부지방법원 고양지원 남양주지원
  인천지방법원 부천지원
].freeze

def self.priority_court_codes
  priority = PRIORITY_COURTS.filter_map { |name| [name, COURT_CODES[name]] if COURT_CODES[name] }
  remaining = COURT_CODES.reject { |name, _| PRIORITY_COURTS.include?(name) }.to_a
  priority + remaining
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/adapters/court_auction/case_search_client_test.rb -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/adapters/court_auction/case_search_client.rb test/adapters/court_auction/case_search_client_test.rb
git commit -m "feat: add priority court ordering to CaseSearchClient"
```

---

### Task 2: Add find_by_case_number to CaseSearchService

**Files:**
- Modify: `app/services/case_search_service.rb`
- Modify: `test/services/case_search_service_test.rb`

- [ ] **Step 1: Write failing test — finds case at first court**

Add to `test/services/case_search_service_test.rb`:

```ruby
# -- find_by_case_number (court discovery) -----------------------------------

test "find_by_case_number discovers court and returns property" do
  stub_case_search_service_sleep!

  # First court returns invalid, second court returns valid
  stub_request(:post, ENDPOINT_URL)
    .to_return(status: 200, body: @invalid_response, headers: json_headers)

  stub_request(:post, ENDPOINT_URL)
    .with(body: hash_including("dma_srchCsDtlInf" => hash_including("cortOfcCd" => "B000530")))
    .to_return(status: 200, body: @valid_response, headers: json_headers)

  # Override priority to test with known court
  CourtAuction::CaseSearchClient.stub(:priority_court_codes, [
    ["서���중앙지방법원", "B000210"],
    ["제주지방법원", "B000530"]
  ]) do
    result = CaseSearchService.find_by_case_number(case_number: "2022타경564")

    assert result.success?
    assert_equal 1, result.properties.size
    assert_equal "2022타경564", result.properties.first.case_number
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/case_search_service_test.rb -n test_find_by_case_number_discovers_court_and_returns_property -v`
Expected: FAIL — `NoMethodError: undefined method 'find_by_case_number'`

- [ ] **Step 3: Write minimal implementation**

Add to `app/services/case_search_service.rb`:

```ruby
def self.find_by_case_number(case_number:)
  new.discover_court(case_number: case_number)
end
```

And the instance method:

```ruby
def discover_court(case_number:)
  delay = BASE_DELAY
  consecutive_errors = 0

  CourtAuction::CaseSearchClient.priority_court_codes.each do |_name, code|
    sleep(delay) unless delay.zero?

    begin
      data = @adapter.search_case(court_code: code, case_number: case_number)

      if data
        property = persist(case_number, data)
        return Result.new(properties: [property], error: nil)
      end

      # Valid response but case not at this court — reset backoff
      delay = BASE_DELAY
      consecutive_errors = 0
    rescue DataProvider::Error => e
      consecutive_errors += 1
      delay = [delay * 2, MAX_DELAY].min

      if consecutive_errors >= MAX_CONSECUTIVE_ERRORS
        log_error(e, case_number)
        return Result.new(properties: [], error: "Court auction site unavailable after #{consecutive_errors} consecutive errors")
      end
    end
  end

  Result.new(properties: [], error: "Case #{case_number} not found at any court")
end
```

Add constants at the top of the class:

```ruby
BASE_DELAY = 0.5
MAX_DELAY = 5.0
MAX_CONSECUTIVE_ERRORS = 5
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/case_search_service_test.rb -n test_find_by_case_number_discovers_court_and_returns_property -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/case_search_service.rb test/services/case_search_service_test.rb
git commit -m "feat: add find_by_case_number with court auto-discovery"
```

- [ ] **Step 6: Write failing test — not found at any court**

Add to `test/services/case_search_service_test.rb`:

```ruby
test "find_by_case_number returns error when case not found at any court" do
  stub_case_search_service_sleep!

  stub_request(:post, ENDPOINT_URL)
    .to_return(status: 200, body: @invalid_response, headers: json_headers)

  CourtAuction::CaseSearchClient.stub(:priority_court_codes, [
    ["서울중앙지방법원", "B000210"],
    ["제주지방법원", "B000530"]
  ]) do
    result = CaseSearchService.find_by_case_number(case_number: "2099타경99999")

    assert_not result.success?
    assert_empty result.properties
    assert_includes result.error, "not found"
  end
end
```

- [ ] **Step 7: Run test to verify it passes** (should already pass)

Run: `bin/rails test test/services/case_search_service_test.rb -n test_find_by_case_number_returns_error_when_case_not_found_at_any_court -v`
Expected: PASS

- [ ] **Step 8: Write failing test — aborts on consecutive HTTP errors**

Add to `test/services/case_search_service_test.rb`:

```ruby
test "find_by_case_number aborts after 5 consecutive HTTP errors" do
  stub_case_search_service_sleep!

  stub_request(:post, ENDPOINT_URL).to_timeout

  courts = 10.times.map { |i| ["Court#{i}", "B00000#{i}"] }

  CourtAuction::CaseSearchClient.stub(:priority_court_codes, courts) do
    result = CaseSearchService.find_by_case_number(case_number: "2026타경1234")

    assert_not result.success?
    assert_includes result.error, "unavailable"
  end

  # Should have stopped after 5, not tried all 10
  assert_requested(:post, ENDPOINT_URL, times: 5)
end
```

- [ ] **Step 9: Run test to verify it passes**

Run: `bin/rails test test/services/case_search_service_test.rb -n test_find_by_case_number_aborts_after_5_consecutive_HTTP_errors -v`
Expected: PASS

- [ ] **Step 10: Write failing test — adaptive backoff resets on success**

Add to `test/services/case_search_service_test.rb`:

```ruby
test "find_by_case_number resets backoff after successful response" do
  stub_case_search_service_sleep!

  # Court 1: timeout (error count 1)
  # Court 2: not found (resets error count)
  # Court 3: timeout (error count 1 again, not 2)
  # Court 4: timeout (error count 2)
  # Court 5: valid (found!)
  courts = [
    ["CourtA", "A001"], ["CourtB", "B001"], ["CourtC", "C001"],
    ["CourtD", "D001"], ["CourtE", "E001"]
  ]

  stub_request(:post, ENDPOINT_URL)
    .with(body: hash_including("dma_srchCsDtlInf" => hash_including("cortOfcCd" => "A001")))
    .to_timeout
  stub_request(:post, ENDPOINT_URL)
    .with(body: hash_including("dma_srchCsDtlInf" => hash_including("cortOfcCd" => "B001")))
    .to_return(status: 200, body: @invalid_response, headers: json_headers)
  stub_request(:post, ENDPOINT_URL)
    .with(body: hash_including("dma_srchCsDtlInf" => hash_including("cortOfcCd" => "C001")))
    .to_timeout
  stub_request(:post, ENDPOINT_URL)
    .with(body: hash_including("dma_srchCsDtlInf" => hash_including("cortOfcCd" => "D001")))
    .to_timeout
  stub_request(:post, ENDPOINT_URL)
    .with(body: hash_including("dma_srchCsDtlInf" => hash_including("cortOfcCd" => "E001")))
    .to_return(status: 200, body: @valid_response, headers: json_headers)

  CourtAuction::CaseSearchClient.stub(:priority_court_codes, courts) do
    result = CaseSearchService.find_by_case_number(case_number: "2022타경564")

    assert result.success?
    assert_equal 1, result.properties.size
  end

  # All 5 courts were tried (didn't abort — error count reset at Court B)
  assert_requested(:post, ENDPOINT_URL, times: 5)
end
```

- [ ] **Step 11: Run test to verify it passes**

Run: `bin/rails test test/services/case_search_service_test.rb -n test_find_by_case_number_resets_backoff_after_successful_response -v`
Expected: PASS

- [ ] **Step 12: Commit**

```bash
git add test/services/case_search_service_test.rb
git commit -m "test: add court discovery edge case tests"
```

---

### Task 3: Add sleep stub helper for CaseSearchService

**Files:**
- Modify: `test/services/case_search_service_test.rb`

The existing `stub_case_search_client_sleep!` stubs sleep on `CaseSearchClient`, but `find_by_case_number` calls sleep on the service itself. We need a helper for that too.

- [ ] **Step 1: Add helper method**

Add to the `private` section of `test/services/case_search_service_test.rb`:

```ruby
def stub_case_search_service_sleep!
  CaseSearchService.prepend(Module.new {
    def sleep(_); end
  })
end

def json_headers
  { "Content-Type" => "application/json" }
end
```

- [ ] **Step 2: Ensure all tests use the stub**

Check that all `find_by_case_number` tests call `stub_case_search_service_sleep!` at the top. (Already included in test code above.)

- [ ] **Step 3: Run all service tests**

Run: `bin/rails test test/services/case_search_service_test.rb -v`
Expected: All PASS

- [ ] **Step 4: Commit**

```bash
git add test/services/case_search_service_test.rb
git commit -m "test: add sleep stub helper for case search service"
```

**Note:** This task can be merged with Task 2 if the helper is added before writing the tests. Listed separately for clarity — the implementer should add the helpers first.

---

### Task 4: Modify PropertiesController#create to use discovery flow

**Files:**
- Modify: `app/controllers/properties_controller.rb`
- Modify: `test/controllers/properties_controller_test.rb`

- [ ] **Step 1: Write failing test — create uses discovery flow for new case**

Replace the existing `"POST create with new case number adds property"` test in `test/controllers/properties_controller_test.rb`:

```ruby
test "POST create with new case number discovers court and adds property" do
  Property.where(case_number: "2026타경88888").destroy_all

  # Step 1: CaseSearchService finds the case (discovery)
  discovery_result = CaseSearchService::Result.new(
    properties: [Property.create!(case_number: "2026타경88888", raw_data: { "csBaseInfo" => { "csNo" => "2026타경88888" } })],
    error: nil
  )

  # Step 2: PropertyDataSyncService fetches full details
  search_fixture = JSON.parse(
    File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
  )
  detail_fixture = JSON.parse(
    File.read(Rails.root.join("test/fixtures/files/court_auction_detail_intercepted.json"))
  )

  mock_client = Object.new
  mock_client.define_singleton_method(:fetch_with_detail) { |**_args|
    { "search" => search_fixture, "detail" => detail_fixture }
  }

  adapter = GovernmentCourtAuctionAdapter.allocate
  adapter.instance_variable_set(:@browser_client, mock_client)
  adapter.instance_variable_set(:@parser, CourtAuction::ResponseParser.new)
  adapter.instance_variable_set(:@rate_limiter,
    CourtAuction::RateLimiter.new(min_interval: 0, max_per_minute: 1000))

  original_adapter_new = GovernmentCourtAuctionAdapter.method(:new)
  GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_args| adapter }

  CaseSearchService.stub(:find_by_case_number, discovery_result) do
    assert_difference "UserProperty.count", 1 do
      post properties_url, params: { case_number: "2026타경88888" }
    end
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "물건이 추가되었습니다", flash[:notice]
  end
ensure
  GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_adapter_new) if original_adapter_new
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/properties_controller_test.rb -n "test_POST_create_with_new_case_number_discovers_court_and_adds_property" -v`
Expected: FAIL — controller still uses old flow

- [ ] **Step 3: Modify PropertiesController#create**

Replace the `else` branch in `app/controllers/properties_controller.rb` `create` method:

```ruby
def create
  case_number = params[:case_number]&.strip

  if case_number.blank?
    redirect_to properties_path, alert: "사건번호를 입력해주세요."
    return
  end

  property = Property.find_by(case_number: case_number)

  if property
    if current_user.user_properties.exists?(property: property)
      redirect_to properties_path, notice: "이미 내 목록에 있는 물���입니다."
    else
      current_user.user_properties.create!(property: property)
      redirect_to properties_path, notice: "이미 등록된 물건입니다. 내 목록에 추가했습니다."
    end
  else
    # Step 1: Discover which court holds this case
    discovery = CaseSearchService.find_by_case_number(case_number: case_number)

    unless discovery.success?
      redirect_to properties_path, alert: discovery_error_message(discovery.error)
      return
    end

    # Step 2: Fetch full details via browser for complete parsing
    result = PropertyDataSyncService.call(case_number: case_number, user: current_user)
    if result.property
      current_user.user_properties.create!(property: result.property)
      redirect_to properties_path, notice: "물���이 추가되었습니다."
    else
      error = result.errors[:court]
      redirect_to properties_path, alert: error_message_for(error)
    end
  end
rescue DataProvider::ParseError => e
  if e.message.include?("Invalid case number format")
    redirect_to properties_path, alert: "사건번호 형식��� 올바르지 않습니다. (예: 2026타경1234)"
  else
    redirect_to properties_path, alert: "데이터 처리 중 오류가 발생했습니다."
  end
end
```

Add private method:

```ruby
def discovery_error_message(error_string)
  if error_string.include?("unavailable")
    "법원경매 사이트에 접속할 수 없습니다. 잠시 후 다시 시도해주세요."
  else
    "해당 사건번호의 물건을 찾을 수 없습니다."
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/properties_controller_test.rb -n "test_POST_create_with_new_case_number_discovers_court_and_adds_property" -v`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/properties_controller.rb test/controllers/properties_controller_test.rb
git commit -m "feat: use court discovery in PropertiesController#create"
```

- [ ] **Step 6: Write test — discovery not found shows error**

Add to `test/controllers/properties_controller_test.rb`:

```ruby
test "POST create shows error when case not found at any court" do
  not_found_result = CaseSearchService::Result.new(
    properties: [],
    error: "Case 2026타��99999 not found at any court"
  )

  CaseSearchService.stub(:find_by_case_number, not_found_result) do
    post properties_url, params: { case_number: "2026타경99999" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "물건을 찾을 수 없습니다", flash[:alert]
  end
end
```

- [ ] **Step 7: Run test**

Run: `bin/rails test test/controllers/properties_controller_test.rb -n "test_POST_create_shows_error_when_case_not_found_at_any_court" -v`
Expected: PASS

- [ ] **Step 8: Write test — discovery site unavailable shows error**

```ruby
test "POST create shows unavailable error when court site is down" do
  unavailable_result = CaseSearchService::Result.new(
    properties: [],
    error: "Court auction site unavailable after 5 consecutive errors"
  )

  CaseSearchService.stub(:find_by_case_number, unavailable_result) do
    post properties_url, params: { case_number: "2026타경99999" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "접속할 수 없습니다", flash[:alert]
  end
end
```

- [ ] **Step 9: Run test**

Run: `bin/rails test test/controllers/properties_controller_test.rb -n "test_POST_create_shows_unavailable_error_when_court_site_is_down" -v`
Expected: PASS

- [ ] **Step 10: Commit**

```bash
git add test/controllers/properties_controller_test.rb
git commit -m "test: add controller tests for discovery error paths"
```

---

### Task 5: Update existing controller tests for new flow

**Files:**
- Modify: `test/controllers/properties_controller_test.rb`

Existing tests that stub `GovernmentCourtAuctionAdapter` for the `create` action need updating since the flow now goes through `CaseSearchService.find_by_case_number` first.

- [ ] **Step 1: Update timeout error test**

Replace `"POST create handles timeout error"` test:

```ruby
test "POST create handles timeout error during detail sync" do
  # Discovery succeeds
  discovery_result = CaseSearchService::Result.new(
    properties: [Property.create!(case_number: "2026타경88888", raw_data: {})],
    error: nil
  )

  # But detail sync fails with timeout
  error_adapter = Object.new
  error_adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
    raise DataProvider::TimeoutError, "timed out"
  end

  original_new = GovernmentCourtAuctionAdapter.method(:new)
  GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_args| error_adapter }

  CaseSearchService.stub(:find_by_case_number, discovery_result) do
    post properties_url, params: { case_number: "2026타경88888" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "시간이 초과", flash[:alert]
  end
ensure
  GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
end
```

- [ ] **Step 2: Update service unavailable error test**

Replace `"POST create handles service unavailable error"` test:

```ruby
test "POST create handles service unavailable during detail sync" do
  discovery_result = CaseSearchService::Result.new(
    properties: [Property.create!(case_number: "2026���경88888", raw_data: {})],
    error: nil
  )

  error_adapter = Object.new
  error_adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
    raise DataProvider::ServiceUnavailableError, "site down"
  end

  original_new = GovernmentCourtAuctionAdapter.method(:new)
  GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_args| error_adapter }

  CaseSearchService.stub(:find_by_case_number, discovery_result) do
    post properties_url, params: { case_number: "2026타경88888" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "접속할 수 없습니��", flash[:alert]
  end
ensure
  GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
end
```

- [ ] **Step 3: Update configuration error test**

Replace `"POST create handles configuration error"` test:

```ruby
test "POST create handles configuration error during detail sync" do
  discovery_result = CaseSearchService::Result.new(
    properties: [Property.create!(case_number: "2026타경88888", raw_data: {})],
    error: nil
  )

  error_adapter = Object.new
  error_adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
    raise DataProvider::ConfigurationError, "no chromium"
  end

  original_new = GovernmentCourtAuctionAdapter.method(:new)
  GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_args| error_adapter }

  CaseSearchService.stub(:find_by_case_number, discovery_result) do
    post properties_url, params: { case_number: "2026타경88888" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "시스템 설정을 확인", flash[:alert]
  end
ensure
  GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
end
```

- [ ] **Step 4: Remove old "POST create with new case number" test**

Delete the test named `"POST create with new case number adds property"` — replaced by the discovery test in Task 4.

- [ ] **Step 5: Run all controller tests**

Run: `bin/rails test test/controllers/properties_controller_test.rb -v`
Expected: All PASS

- [ ] **Step 6: Commit**

```bash
git add test/controllers/properties_controller_test.rb
git commit -m "test: update controller tests for discovery-first flow"
```

---

### Task 6: Run full test suite and verify

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test -v`
Expected: All tests PASS

- [ ] **Step 2: Run rubocop**

Run: `bin/rubocop`
Expected: No new offenses

- [ ] **Step 3: Fix any issues found**

If rubocop reports issues, fix them.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: address rubocop offenses"
```
