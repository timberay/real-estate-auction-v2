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
    assert_text "분석에 실패했습니다"
  end

  test "renders failure_reason when present" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "analysis_status" => "extraction_failed",
      "failure_reason" => "AI 응답에서 rights_analysis 필드를 찾지 못했습니다."
    }
    render_inline(SourceDocViewerComponent.new(report: report, property: report.property))
    assert_text "AI 응답에서 rights_analysis 필드를 찾지 못했습니다"
  end

  test "renders retry button on extraction failure when property given" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "analysis_status" => "extraction_failed" }
    render_inline(SourceDocViewerComponent.new(report: report, property: report.property))
    assert_selector "form[action*='/properties/#{report.property.id}/analyses/retry']"
    assert_text "재시도"
  end

  test "reads tenants from calculated namespace" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => { "tenants" => [], "rights_timeline" => [] },
      "calculated" => {
        "tenants" => [
          { "name" => "김○○", "deposit" => 50_000_000, "opposing_power" => true }
        ]
      },
      "discrepancies" => []
    }
    render_inline(SourceDocViewerComponent.new(report: report))
    assert_text "대항력 있음: 1명"
  end

  test "renders amount_type after amount when present" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => {
        "rights_timeline" => [
          { "date" => "2024-01-15", "type" => "근저당", "holder" => "국민은행",
            "amount" => 200_000_000, "amount_type" => "채권최고액", "extinguished_on_sale" => true }
        ],
        "tenants" => []
      },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }
    render_inline(SourceDocViewerComponent.new(report: report))
    assert_text "채권최고액"
  end

  test "renders amount alone when amount_type absent" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => {
        "rights_timeline" => [
          { "date" => "2024-01-15", "type" => "근저당", "holder" => "국민은행",
            "amount" => 200_000_000, "extinguished_on_sale" => true }
        ],
        "tenants" => []
      },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }
    render_inline(SourceDocViewerComponent.new(report: report))
    assert_text "국민은행"
    refute_match(/nil/i, page.text)
  end
end
