# test/controllers/search_results_controller_inline_test.rb
require "test_helper"

class SearchResultsControllerInlineTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @user = User.find_by(email: "guest@auction.local")
  end

  test "POST create with turbo_stream format returns turbo stream" do
    mock_response = { items: [], total: 0 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create with turbo_stream shows results in stream" do
    mock_items = [
      {
        "srnSaNo" => "2026타경99999",
        "jiwonNm" => "제주지방법원",
        "printSt" => "제주특별자치도 제주시 연동 123",
        "gamevalAmt" => "200000000",
        "minmaePrice" => "140000000",
        "dspslUsgNm" => "아파트",
        "mulJinYn" => "Y",
        "yuchalCnt" => "0",
        "maeGiil" => "2026-05-01",
        "mulBigo" => ""
      }
    ]
    mock_response = { items: mock_items, total: 1 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_match "2026타경99999", response.body
    assert_match "criteria-search-results", response.body
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create with turbo_stream shows error on failure" do
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| raise DataProvider::TimeoutError, "timeout" }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_match "시간이 초과", response.body
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create with turbo_stream marks already-added properties" do
    property = Property.find_by(case_number: "2026타경10001") || properties(:safe_apartment)
    @user.user_properties.find_or_create_by!(property: property)

    mock_items = [
      {
        "srnSaNo" => "2026타경10001",
        "jiwonNm" => "제주지방법원",
        "printSt" => "서울특별시 강남구",
        "gamevalAmt" => "300000000",
        "minmaePrice" => "210000000",
        "dspslUsgNm" => "아파트",
        "mulJinYn" => "Y",
        "yuchalCnt" => "1",
        "maeGiil" => "2026-05-01",
        "mulBigo" => ""
      }
    ]
    mock_response = { items: mock_items, total: 1 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_match "추가됨", response.body
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST inline_import adds property and returns turbo stream" do
    property = properties(:safe_apartment)
    UserProperty.where(user: @user, property: property).destroy_all

    sr = @user.search_results.create!(
      case_number: property.case_number,
      address: "서울특별시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )

    assert_difference "UserProperty.count", 1 do
      post inline_import_search_result_url(sr), as: :turbo_stream
    end
    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
    assert_match "추가됨", response.body
  end

  test "POST inline_import for already-added property shows added state" do
    property = properties(:safe_apartment)
    @user.user_properties.find_or_create_by!(property: property)

    sr = @user.search_results.create!(
      case_number: property.case_number,
      address: "서울특별시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )

    assert_no_difference "UserProperty.count" do
      post inline_import_search_result_url(sr), as: :turbo_stream
    end
    assert_response :success
    assert_match "추가됨", response.body
  end

  test "POST inline_import falls back to search result data when detail fetch fails" do
    sr = @user.search_results.create!(
      case_number: "2026타경88888",
      address: "서울특별시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )

    error_adapter = Object.new
    error_adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
      raise DataProvider::DataNotFoundError, "not found"
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| error_adapter }

    assert_difference [ "Property.count", "UserProperty.count" ], 1 do
      post inline_import_search_result_url(sr), as: :turbo_stream
    end
    assert_response :success
    assert_match "추가됨", response.body

    property = Property.find_by(case_number: "2026타경88888")
    assert_equal "서울특별시", property.address
    assert_equal 200_000_000, property.appraisal_price
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end
end
