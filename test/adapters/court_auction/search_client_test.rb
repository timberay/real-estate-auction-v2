require "test_helper"

class CourtAuction::SearchClientTest < ActiveSupport::TestCase
  setup do
    @client = CourtAuction::SearchClient.new
    @search_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_response.json"))
    )
    @empty_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
  end

  test "returns parsed search result on success" do
    stub_request(@search_fixture) do
      result = @client.search(year: "2026", type: "타경", number: "10001")
      assert_equal "B001001", result[:court_code]
      assert_equal "001", result[:item_number]
      assert_equal "서울중앙지방법원", result[:court_name]
      assert_equal "아파트", result[:property_type]
      assert_equal "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호", result[:address]
      assert_equal 800_000_000, result[:appraisal_price]
      assert_equal 560_000_000, result[:min_bid_price]
      assert_equal false, result[:is_partial_share]
      assert_equal 0, result[:failed_bid_count]
      assert_equal "진행", result[:status]
    end
  end

  test "returns nil when no results found" do
    stub_request(@empty_fixture) do
      result = @client.search(year: "2026", type: "타경", number: "99999")
      assert_nil result
    end
  end

  test "raises IpBlockedError on 403" do
    stub_error_request(403) do
      assert_raises(DataProvider::IpBlockedError) do
        @client.search(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  test "raises ServiceUnavailableError on 500" do
    stub_error_request(500) do
      assert_raises(DataProvider::ServiceUnavailableError) do
        @client.search(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  test "raises SiteStructureChangedError when expected keys missing" do
    stub_request({ "unexpected" => "data" }) do
      assert_raises(DataProvider::SiteStructureChangedError) do
        @client.search(year: "2026", type: "타경", number: "10001")
      end
    end
  end

  private

  def stub_request(body, &block)
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/pgj/pgjsearch/searchControllerMain.on") do
        [200, { "Content-Type" => "application/json" }, body.to_json]
      end
    end
    @client.instance_variable_set(:@conn, build_test_conn(stubs))
    yield
    stubs.verify_stubbed_calls
  end

  def stub_error_request(status, &block)
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/pgj/pgjsearch/searchControllerMain.on") do
        [status, { "Content-Type" => "text/html" }, "Error"]
      end
    end
    @client.instance_variable_set(:@conn, build_test_conn(stubs))
    yield
  end

  def build_test_conn(stubs)
    Faraday.new(url: CourtAuction::BaseClient::BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.adapter :test, stubs
    end
  end
end
