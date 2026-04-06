require "test_helper"

class Analyses::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
    get start_onboarding_url
  end

  test "show redirects to property when no report exists" do
    get property_analyses_report_url(@property)
    assert_response :redirect
  end

  test "show renders report when exists" do
    RightsAnalysisReport.create!(
      user: @user, property: @property, verdict: :safe,
      analyzed_at: Time.current, assumed_amount: 0, total_risk_amount: 0,
      report_data: { registry_timeline: [], tenants: [], dividend_simulation: { expected_bid: nil, distribution: [] }, bidder_burden: { assumed_amount: 0, unconfirmed_risk: 0, total_burden: 0, verdict: "safe" }, checklist_references: [] }
    )
    get property_analyses_report_url(@property)
    assert_response :success
  end

  test "update runs dividend simulation with expected bid" do
    report = RightsAnalysisReport.create!(
      user: @user, property: @property, verdict: :safe,
      analyzed_at: Time.current, assumed_amount: 0, total_risk_amount: 0,
      report_data: { registry_timeline: [], tenants: [], dividend_simulation: { expected_bid: nil, distribution: [] }, bidder_burden: { assumed_amount: 0, unconfirmed_risk: 0, total_burden: 0, verdict: "safe" }, checklist_references: [] }
    )
    patch property_analyses_report_url(@property), params: { expected_bid: 150_000_000 }
    assert_response :redirect
    report.reload
    assert_equal 150_000_000, report.report_data.dig("dividend_simulation", "expected_bid")
  end
end
