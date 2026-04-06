require "test_helper"

class RightsAnalysisFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:guest)
    get start_onboarding_url
    @property = PropertyDataSyncService.call(case_number: "2026타경10002")
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "full analysis flow creates report" do
    post property_analyses_start_url(@property)
    assert_redirected_to edit_property_analyses_checklist_url(@property)

    report = RightsAnalysisReport.find_by(user: @user, property: @property)
    assert_not_nil report
    assert_equal "근저당", report.base_right_type
  end

  test "report page shows analysis results" do
    PropertyAnalysisService.call(property: @property, user: @user)
    RightsAnalysisService.call(property: @property, user: @user)

    get property_analyses_report_url(@property)
    assert_response :success
  end

  test "dividend simulation updates report" do
    RightsAnalysisService.call(property: @property, user: @user)

    patch property_analyses_report_url(@property), params: { expected_bid: 100_000_000 }
    assert_redirected_to property_analyses_report_url(@property)

    report = RightsAnalysisReport.find_by(user: @user, property: @property)
    assert_equal 100_000_000, report.report_data.dig("dividend_simulation", "expected_bid")
    assert report.report_data.dig("dividend_simulation", "distribution").any?
  end

  test "HUG opportunity detection works end-to-end" do
    hug_property = PropertyDataSyncService.call(case_number: "2026타경10003")
    UserProperty.find_or_create_by!(user: @user, property: hug_property)

    post property_analyses_start_url(hug_property)

    report = RightsAnalysisReport.find_by(user: @user, property: hug_property)
    assert_equal "hug_waiver", report.opportunity_type
  end
end
