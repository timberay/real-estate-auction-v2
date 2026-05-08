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

  test "merges timeline and tenants in chronological order" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => {
        "rights_timeline" => [
          { "date" => "2023-03-17", "type" => "주택임차권등기", "holder" => "장동영", "amount" => 367_000_000 },
          { "date" => "2024-09-04", "type" => "강제경매개시결정", "holder" => "주택도시보증공사", "amount" => 385_377_865 }
        ]
      },
      "calculated" => {
        "tenants" => [
          { "name" => "장동영", "deposit" => 367_000_000, "move_in_date" => "2021-02-25",
            "confirmed_date" => "2021-01-26", "opposing_power" => true }
        ]
      },
      "discrepancies" => []
    }
    render_inline(RegistryTimelineComponent.new(report: report))

    rendered = page.text
    tenant_pos = rendered.index("장동영 — 전입신고")
    rights_2023_pos = rendered.index("주택임차권등기")
    rights_2024_pos = rendered.index("강제경매개시결정")

    assert tenant_pos < rights_2023_pos, "tenant (2021) should render before right (2023)"
    assert rights_2023_pos < rights_2024_pos, "earlier right should render before later right"
  end

  test "renders code+question pairs for checklist references" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => { "rights_timeline" => [], "checklist_references" => [ "rights-002" ] },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }
    render_inline(RegistryTimelineComponent.new(report: report))
    expected_question = InspectionItem.find_by!(code: "rights-002").question
    assert_text "[rights-002]"
    assert_text expected_question
  end

  test "renders fallback for deleted checklist codes" do
    report = rights_analysis_reports(:safe_apartment_report)
    report.report_data = {
      "llm_raw" => { "rights_timeline" => [], "checklist_references" => [ "tax-007" ] },
      "calculated" => { "tenants" => [] },
      "discrepancies" => []
    }
    render_inline(RegistryTimelineComponent.new(report: report))
    assert_text "[tax-007]"
    assert_text "(삭제된 항목)"
  end
end
