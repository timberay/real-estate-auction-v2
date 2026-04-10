require "test_helper"

class CaseSearchServiceTest < ActiveSupport::TestCase
  ENDPOINT_URL = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

  setup do
    @valid_response = file_fixture("court_auction_case_search_valid.json").read
    @invalid_response = file_fixture("court_auction_case_search_invalid.json").read
  end

  # -- search by full case number -------------------------------------------

  test "saves raw_data to property for valid case number" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    result = CaseSearchService.call(court_code: "B000530", case_number: "2022타경564")

    assert result.success?
    assert_equal 1, result.properties.size

    property = result.properties.first
    assert_equal "2022타경564", property.case_number
    assert_not_nil property.raw_data
    assert_equal "2022타경564전자", property.raw_data.dig("csBaseInfo", "csNo")
  end

  test "returns error for invalid case number" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @invalid_response, headers: { "Content-Type" => "application/json" })

    result = CaseSearchService.call(court_code: "B000530", case_number: "2025타경99999")

    assert_not result.success?
    assert_empty result.properties
    assert_includes result.error, "not found"
  end

  # -- search by serial number (year cycling) --------------------------------

  test "search_by_serial saves all found cases" do
    stub_case_search_client_sleep!

    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @invalid_response, headers: { "Content-Type" => "application/json" })

    stub_request(:post, ENDPOINT_URL)
      .with(body: { "dma_srchCsDtlInf" => { "cortOfcCd" => "B000530", "csNo" => "2022타경564" } })
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    result = CaseSearchService.call_by_serial(court_code: "B000530", serial_number: "564")

    assert result.success?
    assert_equal 1, result.properties.size
    assert_equal "2022타경564", result.properties.first.case_number
  end

  test "search_by_serial returns empty when no results" do
    stub_case_search_client_sleep!

    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @invalid_response, headers: { "Content-Type" => "application/json" })

    result = CaseSearchService.call_by_serial(court_code: "B000530", serial_number: "99999")

    assert_not result.success?
    assert_empty result.properties
  end

  # -- updates existing property --------------------------------------------

  test "updates raw_data on existing property" do
    property = Property.create!(case_number: "2022타경564", address: "old address")

    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    result = CaseSearchService.call(court_code: "B000530", case_number: "2022타경564")

    assert result.success?
    property.reload
    assert_not_nil property.raw_data
    assert_equal "2022타경564전자", property.raw_data.dig("csBaseInfo", "csNo")
  end

  # -- error handling -------------------------------------------------------

  test "handles API connection errors gracefully" do
    stub_request(:post, ENDPOINT_URL).to_timeout

    result = CaseSearchService.call(court_code: "B000530", case_number: "2022타경564")

    assert_not result.success?
    assert_includes result.error, "connection"
  end

  private

  def stub_case_search_client_sleep!
    CourtAuction::CaseSearchClient.prepend(Module.new {
      def sleep(_); end
    })
  end
end
