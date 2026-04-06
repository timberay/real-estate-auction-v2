require "test_helper"

class ReportSummaryComponentTest < ViewComponent::TestCase
  test "renders safe verdict" do
    report = rights_analysis_reports(:safe_apartment_report)
    render_inline(ReportSummaryComponent.new(report: report))
    assert_text "안전"
    assert_text "말소기준권리"
  end

  test "renders danger verdict" do
    report = rights_analysis_reports(:risky_villa_report)
    render_inline(ReportSummaryComponent.new(report: report))
    assert_text "위험"
  end

  test "renders opportunity badge when present" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.opportunity_type = "hug_waiver"
    report.opportunity_reason = "HUG가 대항력을 포기"
    render_inline(ReportSummaryComponent.new(report: report))
    assert_text "안전 기회 물건"
  end

  test "renders assumed amount" do
    report = rights_analysis_reports(:safe_apartment_report)
    render_inline(ReportSummaryComponent.new(report: report))
    assert_text "인수 금액"
  end
end
