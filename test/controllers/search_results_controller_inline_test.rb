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

  test "POST create with turbo_stream excludes already-added properties" do
    @user.user_properties.destroy_all
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
      },
      {
        "srnSaNo" => "2026타경10002",
        "jiwonNm" => "제주지방법원",
        "printSt" => "서울특별시 서초구",
        "gamevalAmt" => "400000000",
        "minmaePrice" => "280000000",
        "dspslUsgNm" => "아파트",
        "mulJinYn" => "Y",
        "yuchalCnt" => "0",
        "maeGiil" => "2026-06-01",
        "mulBigo" => ""
      }
    ]
    mock_response = { items: mock_items, total: 2 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_no_match "2026타경10001", response.body
    assert_match "2026타경10002", response.body
    assert_match "1건", response.body
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create with turbo_stream limits to 20 results and shows over-limit message" do
    mock_items = 25.times.map do |i|
      {
        "srnSaNo" => "2026타경#{60000 + i}",
        "jiwonNm" => "서울중앙지방법원",
        "printSt" => "서울특별시 #{i}구",
        "gamevalAmt" => "#{200_000_000 + i}",
        "minmaePrice" => "#{140_000_000 + i}",
        "dspslUsgNm" => "아파트",
        "mulJinYn" => "Y",
        "yuchalCnt" => "0",
        "maeGiil" => "2026-05-01",
        "mulBigo" => ""
      }
    end
    mock_response = { items: mock_items, total: 25 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_match "20건", response.body
    assert_match "최대 20건까지 조회됩니다", response.body
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST inline_import returns turbo stream with fade-out and card append" do
    property = properties(:safe_apartment)
    UserProperty.where(user: @user, property: property).destroy_all

    sr = @user.search_results.create!(
      case_number: property.case_number,
      address: "서울특별시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )
    # Create a second search result so remaining_count > 0 after import
    @user.search_results.create!(
      case_number: "2026타경11111",
      address: "부산광역시",
      appraisal_price: 150_000_000,
      min_bid_price: 105_000_000
    )

    assert_difference "UserProperty.count", 1 do
      post inline_import_search_result_url(sr), as: :turbo_stream
    end
    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
    assert_match "fade-remove", response.body
    assert_match "property-cards-grid", response.body
    assert_match "criteria-search-count", response.body
  end

  test "POST inline_import for already-added property returns turbo stream" do
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
    assert_match "fade-remove", response.body
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
    assert_match "fade-remove", response.body
    assert_match "property-cards-grid", response.body

    property = Property.find_by(case_number: "2026타경88888")
    assert_equal "서울특별시", property.address
    assert_equal 200_000_000, property.appraisal_price
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST inline_import clears results box when last item is imported" do
    sr = @user.search_results.create!(
      case_number: "2026타경77777",
      address: "서울특별시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )
    Property.find_or_create_by!(case_number: "2026타경77777") do |p|
      p.address = "서울특별시"
      p.appraisal_price = 200_000_000
      p.min_bid_price = 140_000_000
    end

    post inline_import_search_result_url(sr), as: :turbo_stream
    assert_response :success
    # When remaining count is 0, the entire results container should be cleared
    assert_match(/update.*criteria-search-results/, response.body)
  end

  test "DELETE clear removes all search results and returns turbo stream" do
    3.times do |i|
      @user.search_results.create!(
        case_number: "2026타경#{90000 + i}",
        address: "서울특별시",
        appraisal_price: 100_000_000,
        min_bid_price: 70_000_000
      )
    end

    assert_difference "SearchResult.count", -3 do
      delete clear_search_results_url, as: :turbo_stream
    end
    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
  end

  test "properties index renders persisted search results on load" do
    @user.search_results.create!(
      case_number: "2026타경55555",
      address: "부산광역시",
      appraisal_price: 150_000_000,
      min_bid_price: 105_000_000
    )

    get properties_url
    assert_response :success
    assert_match "2026타경55555", response.body
    assert_match "criteria-search-results", response.body
    assert_no_match "닫기", response.body
  end

  test "properties index does not render results box when no search results" do
    @user.search_results.destroy_all

    get properties_url
    assert_response :success
    assert_no_match(/조건검색 결과/, response.body)
  end
end
