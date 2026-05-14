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
    assert_equal "USER-EDITED ADDRESS", existing.address
  end

  test "race condition: concurrent insert resolves to existing Property" do
    stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)
    Property.create!(case_number: "2022타경564", appraisal_price: 1, min_bid_price: 1, address: "EXISTING")

    result = CaseSearchService.call(court_code: "B000530", case_number: "2022타경564")
    assert result.success?
    assert_equal "EXISTING", result.properties.first.address
  end

  # D3c — exercises the rescue branch in CaseSearchService#persist that handles a
  # TOCTOU race: between `find_or_create_by!` checking for existence and inserting,
  # a sibling request inserts the same case_number, raising RecordNotUnique.
  # The previous "race condition" test pre-creates the row so `find_or_create_by!`
  # short-circuits on the find — it never reaches the rescue. Here we force the
  # raise via a singleton-method stub (project convention: see ApplicationHelperTest).
  test "race condition (rescue branch): RecordNotUnique resolves to existing Property" do
    stub_request(:post, ENDPOINT).to_return(status: 200, body: @fixture)
    existing = Property.create!(
      case_number: "2022타경564",
      appraisal_price: 1,
      min_bid_price: 1,
      address: "EXISTING-AFTER-RACE"
    )

    with_property_find_or_create_raising do
      result = CaseSearchService.call(court_code: "B000530", case_number: "2022타경564")
      assert result.success?
      assert_equal existing.id, result.properties.first.id
      assert_equal "EXISTING-AFTER-RACE", result.properties.first.address
    end
  end

  private

  # Minitest 6 dropped minitest/mock, so use the project's singleton-method
  # stub pattern (see ApplicationHelperTest#with_stubbed_count).
  def with_property_find_or_create_raising
    sc = Property.singleton_class
    sc.send(:define_method, :find_or_create_by!) do |*_args, &_blk|
      raise ActiveRecord::RecordNotUnique, "simulated TOCTOU race"
    end
    yield
  ensure
    sc.send(:remove_method, :find_or_create_by!) if sc.instance_methods(false).include?(:find_or_create_by!)
  end
end
