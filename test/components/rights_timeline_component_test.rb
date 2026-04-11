require "test_helper"

class RightsTimelineComponentTest < ViewComponent::TestCase
  test "renders rights sorted by date" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => {
        "rights_timeline" => [
          { "date" => "2024-08-10", "type" => "가압류", "holder" => "이○○", "amount" => 10_000_000, "extinguished_on_sale" => true },
          { "date" => "2024-01-15", "type" => "근저당권", "holder" => "○○은행", "amount" => 200_000_000, "extinguished_on_sale" => true }
        ]
      },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }
    render_inline(RightsTimelineComponent.new(report: report))
    assert_text "○○은행"
    assert_text "이○○"
    assert_text "말소기준권리"
  end

  test "extinguished rights have strikethrough style" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => {
        "rights_timeline" => [
          { "date" => "2024-01-15", "type" => "근저당권", "holder" => "○○은행", "amount" => 200_000_000, "extinguished_on_sale" => true }
        ]
      },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }
    render_inline(RightsTimelineComponent.new(report: report))
    assert_selector "[data-status='extinguished']"
    assert_text "소멸"
  end

  test "assumed rights have danger style" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => {
        "rights_timeline" => [
          { "date" => "2023-01-01", "type" => "전세권", "holder" => "정○○", "amount" => 50_000_000, "extinguished_on_sale" => false }
        ]
      },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }
    render_inline(RightsTimelineComponent.new(report: report))
    assert_selector "[data-status='assumed']"
    assert_text "인수"
  end

  test "renders opposing-power tenants on timeline" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => { "rights_timeline" => [] },
      "calculated" => {
        "tenants" => [
          { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
            "opposing_power" => true, "has_priority_repayment" => true, "effective_date" => "2023-06-15" }
        ]
      },
      "discrepancies" => []
    }
    render_inline(RightsTimelineComponent.new(report: report))
    assert_text "김○○"
    assert_text "대항력"
  end

  test "renders empty state when no data" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => { "rights_timeline" => [] },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }
    render_inline(RightsTimelineComponent.new(report: report))
    assert_text "권리 설정 내역이 없습니다"
  end
end
