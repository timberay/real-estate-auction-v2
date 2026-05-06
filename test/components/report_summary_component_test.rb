require "test_helper"

class ReportSummaryComponentTest < ViewComponent::TestCase
  test "renders verdict summary text" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "말소기준권리"
  end

  test "does not duplicate the overall verdict (no emoji, label, or 체크리스트 분석 결과 text)" do
    # The overall verdict already lives on the inspection tab bar / bid opinion box.
    # Repeating it here as 🔴 위험 conflicted with the overall 주의 verdict and confused users.
    report = rights_analysis_reports(:risky_villa_report)
    property = properties(:risky_villa)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_no_text "체크리스트 분석 결과"
    assert_no_text "🔴"
    assert_no_text "🟡"
    assert_no_text "🟢"
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

  test "formats assumed and total risk amounts in 만원, not raw 원" do
    # risky_villa_report.assumed_amount = 30_000_000 → 3,000만원
    report = rights_analysis_reports(:risky_villa_report)
    property = properties(:risky_villa)
    render_inline(ReportSummaryComponent.new(report: report, property: property))
    assert_text "3,000만원"
    assert_no_text "30,000,000원"
  end
end
