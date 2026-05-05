require "test_helper"
require "ostruct"

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
    assert_redirected_to search_path
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
    assert_redirected_to search_path
    follow_redirect!
    assert_match "시간이 초과", flash[:alert]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "create redirects to /search with notice on success" do
    original_call = CourtAuctionSearchService.method(:call)
    CourtAuctionSearchService.define_singleton_method(:call) { |**_| OpenStruct.new(error: nil, count: 5) }

    post search_results_url
    assert_redirected_to search_path
  ensure
    CourtAuctionSearchService.define_singleton_method(:call, original_call)
  end

  test "create redirects to /search with alert on error" do
    original_call = CourtAuctionSearchService.method(:call)
    CourtAuctionSearchService.define_singleton_method(:call) { |**_| OpenStruct.new(error: :timeout, count: 0) }

    post search_results_url
    assert_redirected_to search_path
  ensure
    CourtAuctionSearchService.define_singleton_method(:call, original_call)
  end

  test "POST import adds property to user list" do
    sr = @user.search_results.create!(case_number: "2026타경10001", address: "서울")

    # Property already exists in fixtures
    post import_search_result_url(sr)
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "목록에 추가", flash[:notice]
  end

  test "POST import backfills missing court info on existing property when search_result has it" do
    # Existing property predates the court_code/court_name columns and has nils
    property = Property.create!(case_number: "2025타경7777", address: "제주", appraisal_price: 100_000_000, min_bid_price: 80_000_000)
    assert_nil property.court_code
    assert_nil property.court_name

    sr = @user.search_results.create!(case_number: "2025타경7777", court_code: "B000530", court_name: "제주지방법원", address: "제주", appraisal_price: 100_000_000, min_bid_price: 80_000_000)

    post import_search_result_url(sr)
    assert_redirected_to properties_path

    property.reload
    assert_equal "B000530", property.court_code
    assert_equal "제주지방법원", property.court_name
  end

  test "POST import does not overwrite existing court info" do
    property = Property.create!(case_number: "2025타경8888", court_code: "B000280", court_name: "대전지방법원", address: "대전", appraisal_price: 100_000_000, min_bid_price: 80_000_000)
    sr = @user.search_results.create!(case_number: "2025타경8888", court_code: "B000530", court_name: "제주지방법원", address: "대전", appraisal_price: 100_000_000, min_bid_price: 80_000_000)

    post import_search_result_url(sr)

    property.reload
    assert_equal "B000280", property.court_code
    assert_equal "대전지방법원", property.court_name
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

  test "clear (HTML) redirects to /search" do
    @user.search_results.create!(case_number: "2024타경1", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 1, min_bid_price: 1)

    delete clear_search_results_url

    assert_redirected_to search_path
  end

  test "inline_import returns Turbo Stream that replaces card with already_added badge" do
    sr = @user.search_results.create!(case_number: "2024타경7777", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 100_000_000, min_bid_price: 80_000_000)

    post inline_import_search_result_url(sr), as: :turbo_stream

    assert_response :success
    assert_match(/turbo-stream action="replace"/, response.body)
    assert_match dom_id(sr, :inline), response.body
    assert_match "이미 추가됨", response.body

    # 분리 후 property-cards-grid는 search 페이지에 없음 → append 스트림 미포함
    assert_no_match(/property-cards-grid/, response.body)
  end

  test "inline_import is idempotent — second call does not create duplicate user_property" do
    sr = @user.search_results.create!(case_number: "2024타경8888", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 100_000_000, min_bid_price: 80_000_000)

    post inline_import_search_result_url(sr), as: :turbo_stream
    count_after_first = @user.user_properties.count

    post inline_import_search_result_url(sr), as: :turbo_stream
    assert_equal count_after_first, @user.user_properties.count
  end
end
