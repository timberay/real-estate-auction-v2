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
