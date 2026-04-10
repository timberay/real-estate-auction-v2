require "test_helper"

class PropertyDataSyncServiceTest < ActiveSupport::TestCase
  setup do
    @search_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
    )
    @detail_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_detail_intercepted.json"))
    )
  end

  test "creates new property with court data" do
    with_stubbed_adapter(@search_fixture, @detail_fixture) do
      Property.where(case_number: "2026타경10001").destroy_all
      assert_difference "Property.count", 1 do
        result = PropertyDataSyncService.call(case_number: "2026타경10001")
        property = result.property

        assert_equal "2026타경10001", property.case_number
        assert_equal "아파트", property.property_type
        assert_equal "서울특별시 강남구 역삼동 100-1 테스트아파트 101동 1001호", property.address
        assert_equal 800_000_000, property.appraisal_price
        assert_equal 560_000_000, property.min_bid_price
      end
    end
  end

  test "creates sale_detail from detail data" do
    with_stubbed_adapter(@search_fixture, @detail_fixture) do
      Property.where(case_number: "2026타경10001").destroy_all

      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      detail = result.property.sale_detail

      assert_not_nil detail
      assert_equal "부동산임의경매", result.property.case_type
      assert_equal "2024.01.15 근저당 설정", detail.senior_mortgage_basis
      assert_equal 800_000_000, detail.price_round_1
      assert_equal 560_000_000, detail.price_round_2
    end
  end

  test "creates auction_schedules from detail data" do
    with_stubbed_adapter(@search_fixture, @detail_fixture) do
      Property.where(case_number: "2026타경10001").destroy_all

      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      schedules = result.property.auction_schedules

      assert_equal 2, schedules.count
      assert_equal Date.new(2026, 5, 1), schedules.order(:schedule_date).last.schedule_date
    end
  end

  test "creates land_details from detail data" do
    with_stubbed_adapter(@search_fixture, @detail_fixture) do
      Property.where(case_number: "2026타경10001").destroy_all

      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      lands = result.property.land_details

      assert_equal 1, lands.count
      assert_equal "대", lands.first.land_type
    end
  end

  test "creates appraisal_points from detail data" do
    with_stubbed_adapter(@search_fixture, @detail_fixture) do
      Property.where(case_number: "2026타경10001").destroy_all

      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      points = result.property.appraisal_points

      assert_equal 2, points.count
      assert_equal "01", points.first.item_code
    end
  end

  test "upserts existing property without duplicating" do
    with_stubbed_adapter(@search_fixture, @detail_fixture) do
      Property.where(case_number: "2026타경10001").destroy_all

      PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_no_difference "Property.count" do
        result = PropertyDataSyncService.call(case_number: "2026타경10001")
        assert_equal "2026타경10001", result.property.case_number
      end
    end
  end

  test "returns Result with court_data, errors, property" do
    with_stubbed_adapter(@search_fixture, @detail_fixture) do
      Property.where(case_number: "2026타경10001").destroy_all

      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_respond_to result, :court_data
      assert_respond_to result, :errors
      assert_respond_to result, :property
    end
  end

  test "returns nil property when case not found" do
    empty_search = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_empty_search.json"))
    )
    with_stubbed_adapter(empty_search, nil) do
      result = PropertyDataSyncService.call(case_number: "2026타경99999")
      assert_nil result.property
      assert_nil result.court_data
    end
  end

  test "captures DataProvider errors in result.errors" do
    error_adapter = Object.new
    error_adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
      raise DataProvider::TimeoutError, "timed out"
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |**_kwargs| error_adapter }
    begin
      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_nil result.property
      assert result.errors.key?(:court)
      assert_instance_of DataProvider::TimeoutError, result.errors[:court]
    ensure
      GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new.unbind)
    end
  end

  test "accepts user parameter" do
    with_stubbed_adapter(@search_fixture, @detail_fixture) do
      Property.where(case_number: "2026타경10001").destroy_all

      user = users(:guest)
      result = PropertyDataSyncService.call(case_number: "2026타경10001", user: user)
      assert result.court_data.present?
      assert result.property.present?
    end
  end

  include ActiveJob::TestHelper

  test "enqueues AiInspectionJob after successful sync" do
    with_stubbed_adapter(@search_fixture, @detail_fixture) do
      Property.where(case_number: "2026타경10001").destroy_all

      assert_enqueued_with(job: AiInspectionJob) do
        PropertyDataSyncService.call(case_number: "2026타경10001")
      end
    end
  end

  private

  def with_stubbed_adapter(search_response, detail_response)
    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_with_detail) do |**_args|
      { "search" => search_response, "detail" => detail_response }
    end

    adapter = GovernmentCourtAuctionAdapter.allocate
    adapter.instance_variable_set(:@browser_client, mock_client)
    adapter.instance_variable_set(:@parser, CourtAuction::ResponseParser.new)
    adapter.instance_variable_set(:@rate_limiter,
      CourtAuction::RateLimiter.new(min_interval: 0, max_per_minute: 1000))

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |**_kwargs| adapter }
    yield
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new.unbind)
  end
end
