require "test_helper"

class PropertiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url  # creates guest session
  end

  test "GET index shows user properties" do
    get properties_url
    assert_response :success
  end

  test "GET index filters by safety_rating" do
    get properties_url, params: { safety_rating: "safe" }
    assert_response :success
  end

  test "GET show loads property and user_property" do
    get property_url(properties(:safe_apartment))
    assert_response :success
  end

  test "POST create with new case number adds property" do
    # Stub the adapter to return fixture data
    search_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_search_intercepted.json"))
    )
    detail_fixture = JSON.parse(
      File.read(Rails.root.join("test/fixtures/files/court_auction_detail_intercepted.json"))
    )

    mock_client = Object.new
    mock_client.define_singleton_method(:fetch_with_detail) do |**_args|
      { "search" => search_fixture, "detail" => detail_fixture }
    end

    adapter = GovernmentCourtAuctionAdapter.allocate
    adapter.instance_variable_set(:@browser_client, mock_client)
    adapter.instance_variable_set(:@parser, CourtAuction::ResponseParser.new)
    adapter.instance_variable_set(:@rate_limiter,
      CourtAuction::RateLimiter.new(min_interval: 0, max_per_minute: 1000))

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_args| adapter }

    # Use a case number that matches the fixture
    Property.where(case_number: "2026타경10001").destroy_all
    UserProperty.where(user: User.find_by(email: "guest@auction.local")).where(
      property: Property.find_by(case_number: "2026타경10001")
    ).destroy_all

    assert_difference "Property.count", 1 do
      assert_difference "UserProperty.count", 1 do
        post properties_url, params: { case_number: "2026타경10001" }
      end
    end
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "물건이 추가되었습니다", flash[:notice]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create with existing case number adds to user list" do
    # guest already has safe_apartment via fixture; remove it first
    UserProperty.where(
      user: User.find_by(email: "guest@auction.local"),
      property: properties(:safe_apartment)
    ).destroy_all

    assert_no_difference "Property.count" do
      assert_difference "UserProperty.count", 1 do
        post properties_url, params: { case_number: "2026타경10001" }
      end
    end
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "이미 등록된 물건입니다", flash[:notice]
  end

  test "POST create with already-added case number shows notice" do
    # guest already has safe_apartment via fixture
    post properties_url, params: { case_number: "2026타경10001" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "이미 내 목록에 있는 물건입니다", flash[:notice]
  end

  test "POST create with blank case number shows alert" do
    post properties_url, params: { case_number: "" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "사건번호를 입력해주세요", flash[:alert]
  end

  test "GET index renders successfully when user has no budget setting" do
    # guest user has no budget_setting — should render without error
    get properties_url
    assert_response :success
    assert_no_match "예산 초과", response.body
  end

  test "GET show redirects to rating when analysis complete" do
    property = properties(:safe_apartment)
    user_property = user_properties(:guest_safe_apartment)
    user_property.update!(safety_rating: "safe", analyzed_at: Time.current)

    get property_url(property)
    assert_redirected_to property_inspections_grade_path(property)
  end

  test "GET show redirects to checklist when analysis started but no rating" do
    property = properties(:safe_apartment)
    user_property = user_properties(:guest_safe_apartment)
    user_property.update!(safety_rating: nil, analyzed_at: Time.current)

    get property_url(property)
    assert_redirected_to edit_property_inspections_tab_path(property, tab_key: "rights_analysis")
  end

  test "GET show renders pre-analysis state when no analysis" do
    property = properties(:unanalyzed_officetel)

    get property_url(property)
    assert_response :success
    assert_select "button", text: "분석 시작"
  end

  test "POST create with invalid case number format shows format error" do
    post properties_url, params: { case_number: "invalid-format" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "사건번호 형식이 올바르지 않습니다", flash[:alert]
  end

  test "POST create handles timeout error" do
    error_adapter = Object.new
    error_adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
      raise DataProvider::TimeoutError, "timed out"
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_args| error_adapter }

    post properties_url, params: { case_number: "2026타경88888" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "시간이 초과", flash[:alert]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create handles service unavailable error" do
    error_adapter = Object.new
    error_adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
      raise DataProvider::ServiceUnavailableError, "site down"
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_args| error_adapter }

    post properties_url, params: { case_number: "2026타경88888" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "접속할 수 없습니다", flash[:alert]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create handles configuration error" do
    error_adapter = Object.new
    error_adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
      raise DataProvider::ConfigurationError, "no chromium"
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_args| error_adapter }

    post properties_url, params: { case_number: "2026타경88888" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "시스템 설정을 확인", flash[:alert]
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end
end
