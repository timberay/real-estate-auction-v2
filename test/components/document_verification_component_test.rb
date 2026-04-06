require "test_helper"

class DocumentVerificationComponentTest < ViewComponent::TestCase
  test "renders verification prompt" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(DocumentVerificationComponent.new(report: report, property: property))
    assert_text "물건명세서 및 건축물대장과 동일한지 확인"
  end

  test "renders key analysis items from verdict_summary" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(DocumentVerificationComponent.new(report: report, property: property))
    assert_text "말소기준권리"
  end

  test "renders confirm button" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(DocumentVerificationComponent.new(report: report, property: property))
    assert_selector "input[type='submit'][value='예, 동일합니다']"
  end

  test "renders disabled no button" do
    report = rights_analysis_reports(:safe_apartment_report)
    property = properties(:safe_apartment)
    render_inline(DocumentVerificationComponent.new(report: report, property: property))
    assert_selector "button[disabled]", text: "아니오"
  end

  test "shows already confirmed state" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.user_confirmed_at = Time.current
    property = properties(:safe_apartment)
    render_inline(DocumentVerificationComponent.new(report: report, property: property))
    assert_text "확인 완료"
  end
end
