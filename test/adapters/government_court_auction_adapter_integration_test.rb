require "test_helper"

class GovernmentCourtAuctionAdapterIntegrationTest < ActiveSupport::TestCase
  setup do
    @fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
    )
    @empty_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
    @detail_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_detail_intercepted.json"))
    )
  end

  test "fetch_data returns normalized hash with core fields" do
    adapter = build_adapter(@fixture)
    result = adapter.fetch_data(case_number: "2026타경10001")

    assert_equal "2026타경10001", result[:case_number]
    assert_equal "아파트", result[:property_type]
    assert_equal "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호", result[:address]
    assert_equal "서울특별시", result[:sido]
    assert_equal "강남구", result[:sigungu]
    assert_equal 800_000_000, result[:appraisal_price]
    assert_equal 560_000_000, result[:min_bid_price]
  end

  test "fetch_data returns structured fields for inspection" do
    adapter = build_adapter(@fixture)
    result = adapter.fetch_data(case_number: "2026타경10001")

    assert_equal "일괄매각", result[:remarks]
    assert_equal 2, result[:failed_bid_count]
    assert_equal 45, result[:view_count]
    assert_equal "서울특별시", result[:sido]
    assert_equal "강남구", result[:sigungu]
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

  test "fetch_data_with_detail returns merged search + detail data" do
    adapter = build_adapter_with_detail(@fixture, @detail_fixture)
    result = adapter.fetch_data_with_detail(case_number: "2026타경10001")

    # From search
    assert_equal "2026타경10001", result[:case_number]
    assert_equal "아파트", result[:property_type]
    assert_equal 800_000_000, result[:appraisal_price]

    # From detail - csBaseInfo
    assert_equal "부동산임의경매", result[:case_type]
    assert_equal 350_000_000, result[:claim_amount]

    # From detail - dspslGdsDxdyInfo
    assert_nil result[:non_extinguished_rights], "해당사항없음 should be normalized to nil"
    assert_equal "2024.01.15 근저당 설정", result[:senior_mortgage_basis]
    assert_equal 800_000_000, result[:price_round_1]
    assert_equal 560_000_000, result[:price_round_2]

    # Auction schedules
    assert_equal 2, result[:auction_schedules].length
    first_schedule = result[:auction_schedules].first
    assert_equal Date.new(2026, 5, 1), first_schedule[:schedule_date]
    assert_equal "10:00", first_schedule[:schedule_time]

    # Land details
    assert_equal 1, result[:land_details].length
    assert_equal "대", result[:land_details].first[:land_type]

    # Appraisal points
    assert_equal 2, result[:appraisal_points].length
    assert_equal "01", result[:appraisal_points].first[:item_code]
  end

  test "fetch_data_with_detail returns nil when case not found" do
    adapter = build_adapter_with_detail(@empty_fixture, nil)
    result = adapter.fetch_data_with_detail(case_number: "2026타경99999")

    assert_nil result
  end

  private

  def build_adapter(browser_response)
    adapter = GovernmentCourtAuctionAdapter.new

    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_with_detail) do |**_args|
      { "search" => browser_response, "detail" => nil }
    end

    adapter.instance_variable_set(:@browser_client, mock_client)
    adapter.instance_variable_set(
      :@rate_limiter,
      CourtAuction::RateLimiter.new(min_interval: 0, max_per_minute: 1000)
    )

    adapter
  end

  def build_adapter_with_detail(search_response, detail_response)
    adapter = GovernmentCourtAuctionAdapter.new

    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_with_detail) do |**_args|
      { "search" => search_response, "detail" => detail_response }
    end

    adapter.instance_variable_set(:@browser_client, mock_client)
    adapter.instance_variable_set(
      :@rate_limiter,
      CourtAuction::RateLimiter.new(min_interval: 0, max_per_minute: 1000)
    )

    adapter
  end
end
