require "test_helper"

class RightsAnalysisServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)

    @safe_property = properties(:safe_apartment)
    @safe_property.update!(raw_data: {
      "registry_transcript" => {
        "rights" => [
          { "type" => "근저당", "date" => "2023-06-01", "holder" => "국민은행", "amount" => 500_000_000, "status" => "active", "registry_section" => "을구" }
        ],
        "tenants" => [],
        "hug_waiver" => false,
        "seizures" => []
      }
    })

    @risky_property = properties(:risky_villa)
    @risky_property.update!(raw_data: {
      "registry_transcript" => {
        "rights" => [
          { "type" => "근저당", "date" => "2023-06-01", "holder" => "신한은행", "amount" => 200_000_000, "status" => "active", "registry_section" => "을구" },
          { "type" => "가압류", "date" => "2024-01-15", "holder" => "김철수", "amount" => 30_000_000, "status" => "active", "registry_section" => "을구" }
        ],
        "tenants" => [
          { "name" => "이영희", "move_in_date" => "2023-03-01", "deposit" => 100_000_000, "confirmed_date" => "2023-03-15", "dividend_requested" => true }
        ],
        "hug_waiver" => false,
        "seizures" => [
          { "type" => "압류", "date" => "2024-02-01", "holder" => "국세청", "amount" => 10_000_000 }
        ]
      }
    })
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
    hug_property = properties(:unanalyzed_officetel)
    hug_property.update!(raw_data: {
      "registry_transcript" => {
        "rights" => [
          { "type" => "근저당", "date" => "2024-01-01", "holder" => "우리은행", "amount" => 150_000_000, "status" => "active", "registry_section" => "을구" }
        ],
        "tenants" => [
          { "name" => "박민수", "move_in_date" => "2023-06-01", "deposit" => 80_000_000, "confirmed_date" => "2023-06-15", "dividend_requested" => false }
        ],
        "hug_waiver" => true,
        "seizures" => []
      }
    })
    RightsAnalysisService.call(property: hug_property, user: @user)

    report = RightsAnalysisReport.find_by(property: hug_property, user: @user)
    assert_equal "hug_waiver", report.opportunity_type
  end

  test "compute_verdict handles nil and false field values gracefully" do
    property = properties(:safe_apartment)
    # raw_data already set in setup
    report = RightsAnalysisService.call(property: property, user: @user)

    assert_not_includes report.verdict_summary, "false"
    assert_not_includes report.verdict_summary, "nil"
  end

  test "returns the report" do
    result = RightsAnalysisService.call(property: @safe_property, user: @user)
    assert_kind_of RightsAnalysisReport, result
  end
end
