require "test_helper"

class Properties::RightsAnalysisReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership

    @property = properties(:risky_villa)
    UserProperty.find_or_create_by!(user: @user, property: @property)
    @report = RightsAnalysisReport.find_by!(user: @user, property: @property)
  end

  test "unauthenticated PATCH base_right_date redirects to login" do
    delete auth_logout_path
    patch base_right_date_property_report_path(@property),
      params: { rights_analysis_report: { base_right_date: "2023-07-01" } }
    assert_redirected_to auth_login_path
  end

  test "non-owner PATCH base_right_date returns 404" do
    other_property = properties(:safe_apartment)
    UserProperty.where(user: @user, property: other_property).destroy_all
    patch base_right_date_property_report_path(other_property),
      params: { rights_analysis_report: { base_right_date: "2023-07-01" } }
    assert_response :not_found
  end

  test "PATCH base_right_date persists new date and responds with turbo stream" do
    patch base_right_date_property_report_path(@property),
      params: { rights_analysis_report: { base_right_date: "2023-07-01" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    @report.reload
    assert_equal Date.parse("2023-07-01"), @report.base_right_date
  end

  test "PATCH base_right_date without turbo redirects to property path" do
    patch base_right_date_property_report_path(@property),
      params: { rights_analysis_report: { base_right_date: "2023-08-15" } }

    assert_redirected_to property_path(@property)
    @report.reload
    assert_equal Date.parse("2023-08-15"), @report.base_right_date
  end

  test "PATCH base_right_date with blank date returns unprocessable" do
    original_date = @report.base_right_date
    patch base_right_date_property_report_path(@property),
      params: { rights_analysis_report: { base_right_date: "" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    @report.reload
    assert_equal original_date, @report.base_right_date
  end
end
