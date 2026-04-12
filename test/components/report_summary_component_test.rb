require "test_helper"

class ReportSummaryComponentTest < ViewComponent::TestCase
  test "renders safe verdict with checklist label" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "체크리스트 분석 결과"
    assert_no_text "권리 분석 판정"
    assert_text "안전"
    assert_text "말소기준권리"
  end

  test "renders danger verdict" do
    report = rights_analysis_reports(:risky_villa_report)
    property = properties(:risky_villa)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "위험"
  end

  test "renders appraisal price and min bid price" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "감정가"
    assert_text "최저매각가"
  end

  test "renders checklist review summary" do
    report = rights_analysis_reports(:risky_villa_report)
    property = properties(:risky_villa)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "체크리스트 검토"
  end

  test "renders opportunity badge when present" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.opportunity_type = "hug_waiver"
    report.opportunity_reason = "HUG가 대항력을 포기"
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "안전 기회 물건"
  end

  test "renders assumed amount" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "인수 금액"
  end

  test "formats prices correctly from won to Korean currency" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    # Fixture: appraisal_price=800000000, min_bid_price=560000000
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "8억"
    assert_text "5억 6,000만원"
  end
end
