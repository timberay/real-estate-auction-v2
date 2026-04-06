require "test_helper"

class RightsAnalysisServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @safe_property = PropertyDataSyncService.call(case_number: "2026타경10001")
    @risky_property = PropertyDataSyncService.call(case_number: "2026타경10002")
  end

  test "creates a RightsAnalysisReport for safe property" do
    assert_difference "RightsAnalysisReport.count", 1 do
      RightsAnalysisService.call(property: @safe_property, user: @user)
    end

    report = RightsAnalysisReport.find_by(property: @safe_property, user: @user)
    assert_not_nil report
    assert_equal "근저당", report.base_right_type
    assert report.safe?
    assert_not_nil report.analyzed_at
  end

  test "creates a report for risky property with opposing power tenant" do
    RightsAnalysisService.call(property: @risky_property, user: @user)

    report = RightsAnalysisReport.find_by(property: @risky_property, user: @user)
    assert_not_nil report
    # risky_villa: tenant moved in 2023-03-01, base right 2023-06-01 → has opposing power
    # tenant has dividend_requested: true and confirmed_date → assumed_amount=0, total_risk_amount=0
    # but property has seizure → verdict should be safe (no assumed/unconfirmed risk)
    assert_not_nil report.verdict
    data = report.report_data
    tenants = data["tenants"]
    assert tenants.any? { |t| t["has_opposing_power"] == true }
  end

  test "populates report_data with timeline and tenants" do
    RightsAnalysisService.call(property: @risky_property, user: @user)

    report = RightsAnalysisReport.find_by(property: @risky_property, user: @user)
    data = report.report_data
    assert data.key?("registry_timeline")
    assert data.key?("tenants")
    assert data.key?("dividend_simulation")
    assert data.key?("bidder_burden")
    assert data.key?("checklist_references")
  end

  test "upserts on re-analysis" do
    RightsAnalysisService.call(property: @safe_property, user: @user)

    assert_no_difference "RightsAnalysisReport.count" do
      RightsAnalysisService.call(property: @safe_property, user: @user)
    end
  end

  test "detects HUG opportunity for officetel mock" do
    hug_property = PropertyDataSyncService.call(case_number: "2026타경10003")
    RightsAnalysisService.call(property: hug_property, user: @user)

    report = RightsAnalysisReport.find_by(property: hug_property, user: @user)
    assert_equal "hug_waiver", report.opportunity_type
  end

  test "compute_verdict handles nil and false field values gracefully" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    report = RightsAnalysisService.call(property: property, user: @user)

    assert_not_includes report.verdict_summary, "false"
    assert_not_includes report.verdict_summary, "nil"
  end

  test "returns the report" do
    result = RightsAnalysisService.call(property: @safe_property, user: @user)
    assert_kind_of RightsAnalysisReport, result
  end
end
