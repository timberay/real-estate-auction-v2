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
