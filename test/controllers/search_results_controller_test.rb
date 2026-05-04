require "test_helper"

class SearchResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url # creates guest session
    @user = User.find(session[:user_id])
  end

  test "GET index shows search results" do
    @user.search_results.create!(
      case_number: "2024타경100",
      address: "제주특별자치도 제주시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )

    get search_results_url
    assert_response :success
    assert_match "제주특별자치도", response.body
  end

  test "GET index shows region select when no results" do
    get search_results_url
    assert_response :success
    assert_match "관심 지역", response.body
  end

  test "POST create runs search and redirects" do
    mock_response = { items: [], total: 0 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "0건", flash[:notice]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create shows error on timeout" do
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| raise DataProvider::TimeoutError, "timeout" }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "시간이 초과", flash[:alert]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST import adds property to user list" do
    sr = @user.search_results.create!(case_number: "2026타경10001", address: "서울")

    # Property already exists in fixtures
    post import_search_result_url(sr)
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "목록에 추가", flash[:notice]
  end

  test "index assigns paginated search results and existing case numbers" do
    10.times do |i|
      @user.search_results.create!(case_number: "2024타경#{1000 + i}", court_code: "B000210", court_name: "서울지법", address: "주소 #{i}", appraisal_price: 100_000_000, min_bid_price: 80_000_000)
    end
    @user.update!(last_search_api_total_count: 150)

    get search_results_url

    assert_response :success
    assert_equal 10, assigns(:search_results).size
    assert_equal 1, assigns(:search_page)
    assert_equal 1, assigns(:total_pages)
    assert_equal 150, assigns(:api_total_count)
    assert assigns(:over_api_limit)
    assert_kind_of Set, assigns(:existing_case_numbers)
  end

  test "index supports pagination via search_page param" do
    25.times do |i|
      @user.search_results.create!(case_number: "2024타경#{2000 + i}", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 100_000_000, min_bid_price: 80_000_000)
    end

    get search_results_url, params: { search_page: 2 }

    assert_equal 2, assigns(:search_page)
    assert_equal 5, assigns(:search_results).size
  end
end
