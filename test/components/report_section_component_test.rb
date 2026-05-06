# frozen_string_literal: true

require "test_helper"

class ReportSectionComponentTest < ViewComponent::TestCase
  test "renders number badge and title" do
    render_inline(ReportSectionComponent.new(number: 1, title: "종합 판정", anchor: "verdict")) { "body" }
    assert_text "1"
    assert_text "종합 판정"
  end

  test "renders content block" do
    render_inline(ReportSectionComponent.new(number: 2, title: "기본 정보", anchor: "info")) { "inner content" }
    assert_text "inner content"
  end

  test "anchors section with id" do
    render_inline(ReportSectionComponent.new(number: 3, title: "계산기", anchor: "calc")) { "x" }
    assert_selector "section#section-calc"
  end

  test "renders heading as h2" do
    render_inline(ReportSectionComponent.new(number: 4, title: "권리 분석", anchor: "rights")) { "x" }
    assert_selector "h2", text: "권리 분석"
  end
end
