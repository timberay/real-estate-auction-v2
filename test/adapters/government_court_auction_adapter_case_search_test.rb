require "test_helper"

class GovernmentCourtAuctionAdapterCaseSearchTest < ActiveSupport::TestCase
  ENDPOINT_URL = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

  setup do
    @adapter = GovernmentCourtAuctionAdapter.new
    @valid_response = file_fixture("court_auction_case_search_valid.json").read
    @invalid_response = file_fixture("court_auction_case_search_invalid.json").read

    # Stub sleep on the case_search_client
    @adapter.instance_variable_get(:@case_search_client)
      .define_singleton_method(:sleep) { |_| }
  end

  test "search_case returns case data for valid case number" do
    stub_request(:post, ENDPOINT_URL)
      .with(body: { "dma_srchCsDtlInf" => { "cortOfcCd" => "B000530", "csNo" => "2022타경564" } })
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    result = @adapter.search_case(court_code: "B000530", case_number: "2022타경564")

    assert_not_nil result
    assert_equal "20220130000564", result.dig("dma_csBasInf", "csNo")
  end

  test "search_case returns nil for invalid case" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @invalid_response, headers: { "Content-Type" => "application/json" })

    result = @adapter.search_case(court_code: "B000530", case_number: "2025타경99999")

    assert_nil result
  end

  test "search_case_by_serial cycles through years and returns results" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @invalid_response, headers: { "Content-Type" => "application/json" })

    stub_request(:post, ENDPOINT_URL)
      .with(body: { "dma_srchCsDtlInf" => { "cortOfcCd" => "B000530", "csNo" => "2022타경564" } })
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    results = @adapter.search_case_by_serial(court_code: "B000530", serial_number: "564")

    assert_equal 1, results.size
    assert_equal "2022타경564", results.first[:case_number]
  end

  test "search_case respects rate limiter" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    @adapter.search_case(court_code: "B000530", case_number: "2022타경564")

    rate_limiter = @adapter.instance_variable_get(:@rate_limiter)
    assert_equal 1, rate_limiter.request_count
  end
end
