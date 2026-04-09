require "test_helper"

class GovernmentCourtAuctionAdapterIntegrationTest < ActiveSupport::TestCase
  setup do
    @search_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_response.json"))
    )
    @detail_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_detail_response.json"))
    )
    @empty_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
  end

  test "fetch_data returns normalized hash with all expected keys" do
    adapter = build_adapter(@search_fixture, @detail_fixture)
    result = adapter.fetch_data(case_number: "2026타경10001")

    assert_equal "2026타경10001", result[:case_number]
    assert_equal "서울중앙지방법원", result[:court_name]
    assert_equal "아파트", result[:property_type]
    assert_equal 800_000_000, result[:appraisal_price]
    assert_equal 560_000_000, result[:min_bid_price]
    assert_equal false, result[:lien_reported]
    assert_equal true, result[:use_approval]
  end

  test "fetch_data returns nil when case not found" do
    adapter = build_adapter(@empty_fixture, nil)
    result = adapter.fetch_data(case_number: "2026타경99999")
    assert_nil result
  end

  test "result has same keys as mock adapter" do
    adapter = build_adapter(@search_fixture, @detail_fixture)
    real_result = adapter.fetch_data(case_number: "2026타경10001")
    mock_result = MockCourtAuctionAdapter.new.fetch_data(case_number: "2026타경10001")

    mock_result.each_key do |key|
      assert real_result.key?(key), "Real adapter missing key: #{key}"
    end
  end

  test "raises ParseError for invalid case number" do
    adapter = GovernmentCourtAuctionAdapter.new
    assert_raises(DataProvider::ParseError) do
      adapter.fetch_data(case_number: "invalid")
    end
  end

  private

  def build_adapter(search_response, detail_response)
    search_stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/pgj/pgjsearch/searchControllerMain.on") do
        [200, { "Content-Type" => "application/json" }, search_response.to_json]
      end
    end

    detail_stubs = if detail_response
      Faraday::Adapter::Test::Stubs.new do |stub|
        stub.post("/pgj/pgj15B/selectAuctnCsSrchRslt.on") do
          [200, { "Content-Type" => "application/json" }, detail_response.to_json]
        end
      end
    end

    adapter = GovernmentCourtAuctionAdapter.new
    search_client = adapter.instance_variable_get(:@search_client)
    detail_client = adapter.instance_variable_get(:@detail_client)

    search_conn = Faraday.new(url: CourtAuction::BaseClient::BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.adapter :test, search_stubs
    end
    search_client.instance_variable_set(:@conn, search_conn)

    if detail_response
      detail_conn = Faraday.new(url: CourtAuction::BaseClient::BASE_URL) do |f|
        f.request :json
        f.response :json, content_type: /\bjson$/
        f.adapter :test, detail_stubs
      end
      detail_client.instance_variable_set(:@conn, detail_conn)
    end

    # Use a no-op rate limiter for tests
    adapter.instance_variable_set(:@rate_limiter, CourtAuction::RateLimiter.new(min_interval: 0, max_per_minute: 1000))

    adapter
  end
end
