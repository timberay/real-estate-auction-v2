require "test_helper"

class RightsAnalysisReportTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
  end

  test "valid with required attributes" do
    report = RightsAnalysisReport.new(
      user: @user,
      property: @property,
      verdict: :safe,
      analyzed_at: Time.current
    )
    assert report.valid?
  end

  test "invalid without user" do
    report = RightsAnalysisReport.new(property: @property, verdict: :safe, analyzed_at: Time.current)
    assert_not report.valid?
  end

  test "invalid without property" do
    report = RightsAnalysisReport.new(user: @user, verdict: :safe, analyzed_at: Time.current)
    assert_not report.valid?
  end

  test "enforces unique user-property pair" do
    RightsAnalysisReport.create!(user: @user, property: @property, verdict: :safe, analyzed_at: Time.current)
    duplicate = RightsAnalysisReport.new(user: @user, property: @property, verdict: :caution, analyzed_at: Time.current)
    assert_not duplicate.valid?
  end

  test "verdict enum values" do
    report = RightsAnalysisReport.new(user: @user, property: @property, analyzed_at: Time.current)
    report.verdict = :safe
    assert report.safe?
    report.verdict = :caution
    assert report.caution?
    report.verdict = :danger
    assert report.danger?
  end

  test "user association" do
    assert_respond_to @user, :rights_analysis_reports
  end

  test "property association" do
    assert_respond_to @property, :rights_analysis_reports
  end

  test "checklist_reference_codes reads top-level checklist_references" do
    report = RightsAnalysisReport.new(report_data: { "checklist_references" => [ "rights-002" ] }.to_json)
    assert_equal [ "rights-002" ], report.checklist_reference_codes
  end

  test "checklist_reference_codes reads nested llm_raw.checklist_references" do
    report = RightsAnalysisReport.new(report_data: { "llm_raw" => { "checklist_references" => [ "rights-024" ] } }.to_json)
    assert_equal [ "rights-024" ], report.checklist_reference_codes
  end

  test "checklist_reference_codes prefers nested over top-level when both exist" do
    report = RightsAnalysisReport.new(report_data: {
      "llm_raw" => { "checklist_references" => [ "nested" ] },
      "checklist_references" => [ "topLevel" ]
    }.to_json)
    assert_equal [ "nested" ], report.checklist_reference_codes
  end

  test "checklist_reference_codes returns empty array when data missing" do
    report = RightsAnalysisReport.new(report_data: nil)
    assert_equal [], report.checklist_reference_codes
  end

  test "checklist_reference_codes returns empty array on malformed JSON" do
    report = RightsAnalysisReport.new(report_data: "{not json")
    assert_equal [], report.checklist_reference_codes
  end

  # update_tenant! tests
  setup do
    @report_with_tenants = rights_analysis_reports(:risky_villa_report)
    @report_with_tenants.update!(report_data: {
      "calculated" => {
        "tenants" => [
          { "name" => "홍길동", "deposit" => 30_000_000, "move_in_date" => "2023-01-01",
            "confirmed_date" => "2023-01-05", "opposing_power" => true }
        ]
      }
    }.to_json)
  end

  test "update_tenant! persists changed fields to calculated.tenants" do
    @report_with_tenants.update_tenant!(0, deposit: 25_000_000, move_in_date: "2023-02-01", confirmed_date: "2023-02-05")
    @report_with_tenants.reload
    tenant = @report_with_tenants.effective_tenants.first
    assert_equal 25_000_000, tenant["deposit"]
    assert_equal "2023-02-01", tenant["move_in_date"]
    assert_equal "2023-02-05", tenant["confirmed_date"]
    assert_equal true, tenant["user_edited"]
  end

  test "update_tenant! raises IndexError for out-of-bounds index" do
    assert_raises(IndexError) do
      @report_with_tenants.update_tenant!(99, deposit: 1_000_000)
    end
  end

  test "T2.8: update_tenant! allows clearing move_in_date when explicit blank submitted" do
    @report_with_tenants.update_tenant!(0, move_in_date: "")
    @report_with_tenants.reload
    assert_nil @report_with_tenants.effective_tenants.first["move_in_date"]
    # Other fields untouched
    assert_equal 30_000_000, @report_with_tenants.effective_tenants.first["deposit"]
  end

  test "T2.8: update_tenant! allows clearing confirmed_date when explicit blank submitted" do
    @report_with_tenants.update_tenant!(0, confirmed_date: "")
    @report_with_tenants.reload
    assert_nil @report_with_tenants.effective_tenants.first["confirmed_date"]
  end

  test "T2.8: update_tenant! allows clearing deposit when explicit blank submitted" do
    @report_with_tenants.update_tenant!(0, deposit: "")
    @report_with_tenants.reload
    assert_nil @report_with_tenants.effective_tenants.first["deposit"]
  end

  test "T2.8: update_tenant! preserves fields not present in attrs" do
    # Submit only deposit — move_in_date and confirmed_date must be unchanged.
    @report_with_tenants.update_tenant!(0, deposit: 25_000_000)
    @report_with_tenants.reload
    assert_equal "2023-01-01", @report_with_tenants.effective_tenants.first["move_in_date"]
    assert_equal "2023-01-05", @report_with_tenants.effective_tenants.first["confirmed_date"]
  end

  test "update_tenant! does not mutate other tenants" do
    @report_with_tenants.update!(report_data: {
      "calculated" => {
        "tenants" => [
          { "name" => "홍길동", "deposit" => 30_000_000, "move_in_date" => "2023-01-01", "confirmed_date" => nil, "opposing_power" => true },
          { "name" => "김철수", "deposit" => 10_000_000, "move_in_date" => "2022-06-01", "confirmed_date" => "2022-06-10", "opposing_power" => false }
        ]
      }
    }.to_json)
    @report_with_tenants.update_tenant!(0, deposit: 1_000_000)
    @report_with_tenants.reload
    assert_equal 10_000_000, @report_with_tenants.effective_tenants[1]["deposit"]
  end
end
