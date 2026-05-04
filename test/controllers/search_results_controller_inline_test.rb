# test/controllers/search_results_controller_inline_test.rb
require "test_helper"

class SearchResultsControllerInlineTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @user = User.find(session[:user_id])
  end

  test "POST inline_import persists court_code and court_name from search_result onto new Property" do
    UserProperty.where(user: @user).destroy_all
    Property.where(case_number: "2026타경55555").destroy_all

    sr = @user.search_results.create!(
      case_number: "2026타경55555",
      court_code: "B000530",
      court_name: "제주지방법원",
      address: "제주특별자치도 제주시",
      appraisal_price: 100_000_000,
      min_bid_price: 70_000_000
    )

    assert_difference "Property.count", 1 do
      post inline_import_search_result_url(sr), as: :turbo_stream
    end

    property = Property.find_by!(case_number: "2026타경55555")
    assert_equal "B000530", property.court_code
    assert_equal "제주지방법원", property.court_name
  end

  test "POST inline_import returns turbo stream that replaces card with already_added badge" do
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
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_match "이미 추가됨", response.body
    assert_no_match "property-cards-grid", response.body
  end

  test "POST inline_import for already-added property returns turbo stream with already_added badge" do
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
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_match "이미 추가됨", response.body
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
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_match "이미 추가됨", response.body

    property = Property.find_by(case_number: "2026타경88888")
    assert_equal "서울특별시", property.address
    assert_equal 200_000_000, property.appraisal_price
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST inline_import replaces card with already_added badge (no criteria-search-results clear)" do
    sr = @user.search_results.create!(
      case_number: "2026타경77777",
      address: "서울특별시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )

    post inline_import_search_result_url(sr), as: :turbo_stream
    assert_response :success
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_match "이미 추가됨", response.body
    assert_no_match "criteria-search-results", response.body
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

  test "search index renders persisted search results on load" do
    @user.search_results.create!(
      case_number: "2026타경55555",
      address: "부산광역시",
      appraisal_price: 150_000_000,
      min_bid_price: 105_000_000
    )

    get search_path
    assert_response :success
    assert_match "2026타경55555", response.body
    assert_match "criteria-search-results", response.body
    assert_no_match "닫기", response.body
  end

  test "search index does not render results box when no search results" do
    @user.search_results.destroy_all

    get search_path
    assert_response :success
    assert_no_match(/조건검색 결과/, response.body)
  end

  test "search result card renders court_name and hides court_code" do
    @user.search_results.create!(
      case_number: "2026타경66666",
      court_name: "서울동부지방법원",
      court_code: "B000211",
      address: "서울특별시 강남구",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )

    get search_path
    assert_response :success
    assert_match "서울동부지방법원", response.body
    # court_code must not appear as visible text (it may appear as an option value in the court select)
    assert_no_match ">B000211<", response.body
  end
end
