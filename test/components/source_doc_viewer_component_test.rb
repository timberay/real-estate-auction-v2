require "test_helper"

class SourceDocViewerComponentTest < ViewComponent::TestCase
  test "renders empty message when no report provided" do
    render_inline(SourceDocViewerComponent.new(report: nil))
    assert_text "분석을 먼저 실행해주세요"
  end

  test "renders disclaimer" do
    report = rights_analysis_reports(:safe_apartment_report)
    render_inline(SourceDocViewerComponent.new(report: report))
    assert_text "매각물건명세서 비고란을 직접 확인하세요"
  end

  test "renders error message when extraction failed" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "analysis_status" => "extraction_failed" }
    render_inline(SourceDocViewerComponent.new(report: report))
    assert_text "분석 데이터를 구조화하는 데 실패했습니다"
  end
end
