require "test_helper"

class SearchResultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url # creates guest session
    @user = User.find_by(email: "guest@auction.local")
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

  test "GET index shows empty state when no results" do
    get search_results_url
    assert_response :success
    assert_match "검색 결과가 없습니다", response.body
  end

  test "POST create runs search and redirects" do
    mock_response = { items: [], total: 0 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url
    assert_redirected_to search_results_path
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
    assert_redirected_to search_results_path
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
end
