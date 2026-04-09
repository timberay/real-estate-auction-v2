require "test_helper"

class GovernmentCourtAuctionAdapterIntegrationTest < ActiveSupport::TestCase
  setup do
    @fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
    )
    @empty_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
  end

  test "fetch_data returns normalized hash with core fields" do
    adapter = build_adapter(@fixture)
    result = adapter.fetch_data(case_number: "2026타경10001")

    assert_equal "2026타경10001", result[:case_number]
    assert_equal "서울중앙지방법원", result[:court_name]
    assert_equal "아파트", result[:property_type]
    assert_equal "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호", result[:address]
    assert_equal 800_000_000, result[:appraisal_price]
    assert_equal 560_000_000, result[:min_bid_price]
  end

  test "fetch_data returns raw_data fields for inspection" do
    adapter = build_adapter(@fixture)
    result = adapter.fetch_data(case_number: "2026타경10001")

    assert_equal "일괄매각", result[:remarks]
    assert_equal 2, result[:failed_bid_count]
    assert_equal false, result[:is_partial_share]
    assert_equal 45, result[:view_count]
  end

  test "fetch_data returns nil when case not found" do
    adapter = build_adapter(@empty_fixture)
    result = adapter.fetch_data(case_number: "2026타경99999")

    assert_nil result
  end

  test "raises ParseError for invalid case number" do
    adapter = GovernmentCourtAuctionAdapter.new
    assert_raises(DataProvider::ParseError) do
      adapter.fetch_data(case_number: "invalid")
    end
  end

  test "throttles requests via rate limiter" do
    adapter = build_adapter(@fixture)
    rate_limiter = adapter.instance_variable_get(:@rate_limiter)

    adapter.fetch_data(case_number: "2026타경10001")

    assert_equal 1, rate_limiter.request_count
  end

  private

  def build_adapter(browser_response)
    adapter = GovernmentCourtAuctionAdapter.new

    mock_client = Object.new
    mock_client.define_singleton_method(:fetch) { |**_args| browser_response }

    adapter.instance_variable_set(:@browser_client, mock_client)
    adapter.instance_variable_set(
      :@rate_limiter,
      CourtAuction::RateLimiter.new(min_interval: 0, max_per_minute: 1000)
    )

    adapter
  end
end
