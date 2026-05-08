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
end
