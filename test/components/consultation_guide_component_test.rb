require "test_helper"

class ConsultationGuideComponentTest < ViewComponent::TestCase
  test "not rendered when no risk results" do
    render_inline(ConsultationGuideComponent.new(risk_results: []))
    assert_no_text "전문가 상담 가이드"
  end

  test "renders rights analysis professional for rights tab risks" do
    risk_results = InspectionResult
      .where(has_risk: true, property: properties(:risky_villa), user: users(:guest))
      .includes(:inspection_item)
    render_inline(ConsultationGuideComponent.new(risk_results: risk_results))
    assert_text "법무사/변호사"
  end

  test "renders section title when risks exist" do
    risk_results = InspectionResult
      .where(has_risk: true, property: properties(:risky_villa), user: users(:guest))
      .includes(:inspection_item)
    render_inline(ConsultationGuideComponent.new(risk_results: risk_results))
    assert_text "전문가 상담 가이드"
  end
end
