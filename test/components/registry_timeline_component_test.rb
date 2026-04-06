require "test_helper"

class RegistryTimelineComponentTest < ViewComponent::TestCase
  test "renders timeline entries" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "registry_timeline" => [
        { "date" => "2024-01-15", "type" => "근저당", "holder" => "국민은행", "amount" => 200_000_000 }
      ],
      "tenants" => [],
      "checklist_references" => []
    }
    render_inline(RegistryTimelineComponent.new(report: report))
    assert_text "국민은행"
    assert_text "근저당"
  end

  test "renders empty state when no timeline" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = { "registry_timeline" => [], "tenants" => [], "checklist_references" => [] }
    render_inline(RegistryTimelineComponent.new(report: report))
    assert_text "등기부"
  end
end
