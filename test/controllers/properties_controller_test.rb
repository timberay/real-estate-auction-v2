require "test_helper"
require "json"

class PropertiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url  # creates guest session
    @user = inherit_fixture_guest_ownership
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

  ENDPOINT = "https://www.courtauction.go.kr/pgj/pgj15A/selectAuctnCsSrchRslt.on"

  test "POST create with court_code + new case fetches from court site and adds to user list" do
    fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
    stub_request(:post, ENDPOINT).to_return(status: 200, body: fixture)

    UserProperty.where(user: @user, property: properties(:safe_apartment)).destroy_all

    assert_difference "Property.count", 1 do
      assert_difference "UserProperty.count", 1 do
        post properties_url, params: { court_code: "B000530", case_number: "2022타경564" }
      end
    end
    assert Property.find_by(case_number: "2022타경564")
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "내 목록에 추가했습니다", flash[:notice]
  end

  test "POST create with already-added case number shows notice" do
    fixture = File.read(Rails.root.join("test/fixtures/files/court_auction_case_search_valid.json"))
    body = JSON.parse(fixture)
    body["data"]["dma_csBasInf"]["userCsNo"] = "2026타경10001"
    stub_request(:post, ENDPOINT).to_return(status: 200, body: body.to_json)

    post properties_url, params: { court_code: "B000530", case_number: "2026타경10001" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "내 목록에 추가했습니다", flash[:notice]
  end

  test "POST create with blank case number shows format error" do
    post properties_url, params: { court_code: "B000530", case_number: "" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "사건번호 형식이 올바르지 않습니다", flash[:alert]
  end

  test "POST create with case found-not-at-court shows not-found alert" do
    body = { "data" => { "dma_csBasInf" => { "csNo" => "" } } }.to_json
    stub_request(:post, ENDPOINT).to_return(status: 200, body: body)

    post properties_url, params: { court_code: "B000530", case_number: "2099타경999" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "물건을 찾을 수 없습니다", flash[:alert]
  end

  test "POST create with blank court_code shows format error" do
    post properties_url, params: { court_code: "", case_number: "2024타경881" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "사건번호 형식이 올바르지 않습니다", flash[:alert]
  end

  test "POST create with tampered (non-allow-list) court_code shows format error" do
    post properties_url, params: { court_code: "FAKE_CODE", case_number: "2024타경881" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "사건번호 형식이 올바르지 않습니다", flash[:alert]
  end

  test "POST create with bad case_number format shows format error and makes no HTTP call" do
    post properties_url, params: { court_code: "B000530", case_number: "hello" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "사건번호 형식이 올바르지 않습니다", flash[:alert]
  end

  test "POST create when court site returns 503 shows site-unavailable alert" do
    stub_request(:post, ENDPOINT).to_return(status: 503)

    post properties_url, params: { court_code: "B000530", case_number: "2024타경881" }
    assert_redirected_to properties_path
    follow_redirect!
    assert_match "법원경매 사이트에 접속할 수 없습니다", flash[:alert]
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

  test "DELETE destroy removes user_property and user-scoped analysis data" do
    property = properties(:safe_apartment)
    user = @user

    # Create user-scoped analysis data
    item = inspection_items(:rights_002)
    # Fixture already has inspection_result for this combo, so use a different item
    item2 = inspection_items(:rights_001)
    InspectionResult.create!(property: property, user: user, inspection_item: item2, source_type: :auto)
    RightsAnalysisReport.create!(property: property, user: user, analyzed_at: Time.current, report_data: "{}")
    LlmAnalysisLog.create!(property: property, user: user, system_prompt: "test", user_prompt: "test", status: :completed)

    assert_difference "UserProperty.count", -1 do
      delete property_url(property)
    end

    assert_not InspectionResult.exists?(property: property, user: user)
    assert_not RightsAnalysisReport.exists?(property: property, user: user)
    assert_not LlmAnalysisLog.exists?(property: property, user: user)
    assert Property.exists?(property.id), "Property record itself must be preserved"
    assert_redirected_to properties_path
  end

  test "DELETE destroy responds with turbo_stream to remove card" do
    property = properties(:safe_apartment)

    delete property_url(property), as: :turbo_stream

    assert_response :success
    assert_includes response.body, "turbo-stream"
    assert_includes response.body, "remove"
    assert_includes response.body, "card_property_#{property.id}"
  end

  test "DELETE destroy returns 404 for property not in user list" do
    property = properties(:basement_villa)  # not in guest's list

    delete property_url(property)
    assert_response :not_found
  end

  test "GET show redirects unanalyzed property to AI analysis page" do
    property = properties(:unanalyzed_officetel)

    get property_url(property)
    assert_redirected_to new_analysis_path(property_id: property.id)
  end

  test "index does NOT assign search-related instance vars (moved to SearchResultsController#index)" do
    get properties_url

    assert_response :success
    assert_nil assigns(:search_results)
    assert_nil assigns(:search_page)
    assert_nil assigns(:total_pages)
    assert_nil assigns(:api_total_count)
    assert_nil assigns(:over_api_limit)
  end

  test "index still assigns user_properties and budget vars" do
    get properties_url

    assert_not_nil assigns(:user_properties)
    # @max_bid_amount may be nil if user has no budget — that's OK
  end

  test "index within_budget filter compares min_bid_price (not appraisal_price) against max_bid_amount" do
    # safe_apartment: appraisal=8억, min_bid=5.6억
    # max_bid=6억(60000만원) → appraisal exceeds, min_bid does NOT → property MUST remain visible
    BudgetSetting.create!(user: @user, max_bid_amount: 60000, completed_at: Time.current)

    get properties_url, params: { within_budget: "1" }
    assert_response :success
    assert_includes assigns(:user_properties).map(&:property), properties(:safe_apartment)
  end

  test "PATCH toggle_favorite flips favorite flag and returns turbo_stream" do
    property = user_properties(:guest_safe_apartment).property
    assert_equal false, user_properties(:guest_safe_apartment).favorite

    patch toggle_favorite_property_url(property),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_equal true, user_properties(:guest_safe_apartment).reload.favorite
  end

  test "PATCH toggle_favorite is idempotent on second call (toggles back)" do
    property = user_properties(:guest_safe_apartment).property

    patch toggle_favorite_property_url(property),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    patch toggle_favorite_property_url(property),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_equal false, user_properties(:guest_safe_apartment).reload.favorite
  end

  test "PATCH toggle_favorite redirects on HTML format (Turbo fallback)" do
    property = user_properties(:guest_safe_apartment).property

    patch toggle_favorite_property_url(property)

    assert_redirected_to properties_path
  end

  test "PATCH toggle_favorite returns 404 for property not in user's list" do
    other_property = Property.create!(
      case_number: "9999타경99999", court_name: "테스트법원", address: "테스트"
    )

    patch toggle_favorite_property_url(other_property)
    assert_response :not_found
  end

  test "GET index returns favorited user_properties before non-favorited" do
    get properties_url

    assert_response :success
    body = response.body
    favorited_pos = body.index(user_properties(:guest_favorited_villa).property.case_number)
    non_favorited_pos = body.index(user_properties(:guest_safe_apartment).property.case_number)
    assert favorited_pos < non_favorited_pos,
      "favorited card should appear before non-favorited in HTML"
  end
end
