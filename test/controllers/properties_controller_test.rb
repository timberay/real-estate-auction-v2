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
    assert_difference "Property.count", 1 do
      assert_difference "UserProperty.count", 1 do
        post properties_url, params: { case_number: "2026타경99999" }
      end
    end
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "물건이 추가되었습니다", flash[:notice]
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
end
