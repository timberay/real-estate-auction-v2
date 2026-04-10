require "test_helper"

class CourtAuction::CaseSearchClientTest < ActiveSupport::TestCase
  ENDPOINT_URL = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

  setup do
    @client = CourtAuction::CaseSearchClient.new
    @client.define_singleton_method(:sleep) { |_| } # skip sleep in tests
    @valid_response = file_fixture("court_auction_case_search_valid.json").read
    @invalid_response = file_fixture("court_auction_case_search_invalid.json").read
  end

  # -- search (single case number) -------------------------------------------

  test "search returns parsed data for valid case number" do
    stub_request(:post, ENDPOINT_URL)
      .with(
        body: { "dma_srchCsDtlInf" => { "cortOfcCd" => "B000530", "csNo" => "2022타경564" } },
        headers: { "submissionid" => "mf_wfm_mainFrame_sbm_selectCsDtlInf" }
      )
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    result = @client.search(court_code: "B000530", case_number: "2022타경564")

    assert_not_nil result
    assert_equal "2022타경564전자", result.dig("csBaseInfo", "csNo")
    assert_equal "부동산임의경매", result.dig("csBaseInfo", "csNm")
    assert_equal "260000000", result.dig("csBaseInfo", "clmAmt")
  end

  test "search returns nil for invalid case number" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @invalid_response, headers: { "Content-Type" => "application/json" })

    result = @client.search(court_code: "B000530", case_number: "2025타경99999")

    assert_nil result
  end

  test "search sends correct headers" do
    stub = stub_request(:post, ENDPOINT_URL)
      .with(headers: {
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "submissionid" => "mf_wfm_mainFrame_sbm_selectCsDtlInf",
        "sc-userid" => "NONUSER",
        "sc-pgmid" => "PGJ15AF01"
      })
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    @client.search(court_code: "B000530", case_number: "2022타경564")

    assert_requested stub
  end

  test "search raises ServiceUnavailableError on HTTP failure" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 500, body: "Internal Server Error")

    assert_raises(DataProvider::ServiceUnavailableError) do
      @client.search(court_code: "B000530", case_number: "2022타경564")
    end
  end

  test "search raises ConnectionError on network failure" do
    stub_request(:post, ENDPOINT_URL).to_timeout

    assert_raises(DataProvider::ConnectionError) do
      @client.search(court_code: "B000530", case_number: "2022타경564")
    end
  end

  # -- search_by_serial (year cycling) ---------------------------------------

  test "search_by_serial cycles through years and collects valid results" do
    current_year = Date.current.year

    # Only year 2022 returns a valid result
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @invalid_response, headers: { "Content-Type" => "application/json" })

    stub_request(:post, ENDPOINT_URL)
      .with(body: { "dma_srchCsDtlInf" => { "cortOfcCd" => "B000530", "csNo" => "2022타경564" } })
      .to_return(status: 200, body: @valid_response, headers: { "Content-Type" => "application/json" })

    results = @client.search_by_serial(court_code: "B000530", serial_number: "564")

    assert_equal 1, results.size
    assert_equal 2022, results.first[:year]
    assert_equal "2022타경564", results.first[:case_number]
    assert_not_nil results.first[:data]
  end

  test "search_by_serial returns empty array when no results found" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @invalid_response, headers: { "Content-Type" => "application/json" })

    results = @client.search_by_serial(court_code: "B000530", serial_number: "99999")

    assert_equal [], results
  end

  test "search_by_serial searches 6 years by default" do
    stub_request(:post, ENDPOINT_URL)
      .to_return(status: 200, body: @invalid_response, headers: { "Content-Type" => "application/json" })

    @client.search_by_serial(court_code: "B000530", serial_number: "564")

    current_year = Date.current.year
    (current_year.downto(current_year - 5)).each do |year|
      assert_requested :post, ENDPOINT_URL,
        body: { "dma_srchCsDtlInf" => { "cortOfcCd" => "B000530", "csNo" => "#{year}타경564" } },
        times: 1
    end
  end

  # -- priority court ordering -----------------------------------------------

  test "priority_court_codes returns all courts with priority ones first" do
    codes = CourtAuction::CaseSearchClient.priority_court_codes

    # Contains all 60 courts
    assert_equal CourtAuction::CaseSearchClient::COURT_CODES.size, codes.size

    # Seoul courts come first
    first_5 = codes.first(5).map(&:first)
    assert_includes first_5, "서울중앙지방법원"
    assert_includes first_5, "서울동부지방법원"
    assert_includes first_5, "서울서부지방법원"
    assert_includes first_5, "서울남부지방법원"
    assert_includes first_5, "서울북부지방법원"

    # Gyeonggi courts come next
    next_batch = codes.slice(5, 7).map(&:first)
    assert_includes next_batch, "수원지방법원"
    assert_includes next_batch, "의정부지방법원"
  end

  # -- court code lookup -----------------------------------------------------

  test "court_code_for returns correct code for known court name" do
    assert_equal "B000530", CourtAuction::CaseSearchClient.court_code_for("제주지방법원")
    assert_equal "B000210", CourtAuction::CaseSearchClient.court_code_for("서울중앙지방법원")
  end

  test "court_code_for returns nil for unknown court name" do
    assert_nil CourtAuction::CaseSearchClient.court_code_for("없는법원")
  end

  test "court_names returns all 60 court names" do
    names = CourtAuction::CaseSearchClient.court_names
    assert_equal 60, names.size
    assert_includes names, "서울중앙지방법원"
    assert_includes names, "제주지방법원"
  end
end
