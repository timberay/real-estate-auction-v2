require "test_helper"

class RegistryTimelineComponentTest < ViewComponent::TestCase
  test "renders timeline entries from llm_raw" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => {
        "rights_timeline" => [
          { "date" => "2024-01-15", "type" => "근저당", "holder" => "국민은행", "amount" => 200_000_000, "extinguished_on_sale" => true }
        ]
      },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }
    render_inline(RegistryTimelineComponent.new(report: report))
    assert_text "국민은행"
    assert_text "근저당"
  end

  test "renders tenants from calculated namespace" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => { "rights_timeline" => [] },
      "calculated" => {
        "tenants" => [
          { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
            "confirmed_date" => "2023-06-15", "opposing_power" => true }
        ]
      },
      "discrepancies" => []
    }
    render_inline(RegistryTimelineComponent.new(report: report))
    assert_text "김○○"
    assert_text "대항력 있음"
  end

  test "renders empty state when no data" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "llm_raw" => { "rights_timeline" => [] }, "calculated" => { "tenants" => [] }, "discrepancies" => [] }
    render_inline(RegistryTimelineComponent.new(report: report))
    assert_text "등기부"
  end
end
