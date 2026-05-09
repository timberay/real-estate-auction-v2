# frozen_string_literal: true

require "test_helper"

class RightsReportSectionComponentTest < ViewComponent::TestCase
  setup do
    @property = properties(:safe_apartment)
    @report = rights_analysis_reports(:safe_apartment_report)
  end

  test "accepts show_title arg" do
    component = RightsReportSectionComponent.new(report: @report, property: @property, show_title: false)
    assert_equal false, component.instance_variable_get(:@show_title)
  end

  test "defaults show_title to true" do
    component = RightsReportSectionComponent.new(report: @report, property: @property)
    assert_equal true, component.instance_variable_get(:@show_title)
  end

  test "renders preferred_purchase_risk warning badge" do
    @report.opportunity_type = "preferred_purchase_risk"
    render_inline(RightsReportSectionComponent.new(report: @report, property: @property))
    assert_text "우선매수권 행사 위험"
  end

  # --- B8 / E-41: hug_waiver opportunity citation ---

  test "renders opportunity citation when hug_waiver" do
    @report.opportunity_type = "hug_waiver"
    @report.report_data = {
      "opportunity_evidence" => {
        "source_doc" => "매각물건명세서",
        "page_number" => 5,
        "quote" => "주택도시보증공사는 본 사건의 임차권에 대한 모든 권리를 포기하며 낙찰자에게 인수되지 않음에 동의합니다."
      }
    }.to_json
    render_inline(RightsReportSectionComponent.new(report: @report, property: @property))

    assert_text "매각물건명세서"
    assert_text "p.5"
    assert_text "주택도시보증공사는 본 사건의 임차권에 대한 모든 권리를 포기"
  end

  test "does not render opportunity citation for gap_investment" do
    @report.opportunity_type = "gap_investment"
    @report.report_data = {
      "opportunity_evidence" => {
        "source_doc" => "감정평가서",
        "page_number" => 3,
        "quote" => "이 문서는 갭투자 기회와 관련된 인용이 아닙니다."
      }
    }.to_json
    render_inline(RightsReportSectionComponent.new(report: @report, property: @property))

    # Citation block must NOT render for non-hug_waiver opportunity types
    assert_no_text "감정평가서"
    assert_no_text "p.3"
  end
end
