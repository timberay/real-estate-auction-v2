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
end
