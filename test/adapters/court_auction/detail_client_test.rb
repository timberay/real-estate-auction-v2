require "test_helper"

class CourtAuction::DetailClientTest < ActiveSupport::TestCase
  setup do
    @client = CourtAuction::DetailClient.new
    @detail_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_detail_response.json"))
    )
  end

  test "returns raw detail data on success" do
    stub_request(@detail_fixture) do
      result = @client.fetch(
        court_code: "B001001", year: "2026", type: "타경",
        number: "10001", item_number: "001"
      )
      assert_equal "해당사항 없음", result["bkgsRmk"]
      assert_equal "N", result["lienRptYn"]
      assert_equal "Y", result["useAprYn"]
      assert_kind_of Array, result["dlt_neRghts"]
      assert_kind_of Array, result["dlt_tenants"]
    end
  end

  test "raises SiteStructureChangedError when expected keys missing" do
    stub_request({ "unexpected" => "data" }) do
      assert_raises(DataProvider::SiteStructureChangedError) do
        @client.fetch(
          court_code: "B001001", year: "2026", type: "타경",
          number: "10001", item_number: "001"
        )
      end
    end
  end

  private

  def stub_request(body, &block)
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post("/pgj/pgj15B/selectAuctnCsSrchRslt.on") do
        [200, { "Content-Type" => "application/json" }, body.to_json]
      end
    end
    @client.instance_variable_set(:@conn, build_test_conn(stubs))
    yield
    stubs.verify_stubbed_calls
  end

  def build_test_conn(stubs)
    Faraday.new(url: CourtAuction::BaseClient::BASE_URL) do |f|
      f.request :json
      f.response :json, content_type: /\bjson$/
      f.adapter :test, stubs
    end
  end
end
