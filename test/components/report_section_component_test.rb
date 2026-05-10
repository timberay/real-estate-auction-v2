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

  # --- B24 / B-18: beginner-mode summary line under section title ---

  test "renders beginner_summary when beginner_mode is true and summary is provided" do
    render_inline(
      ReportSectionComponent.new(
        number: 1,
        title: "종합 판정",
        anchor: "verdict",
        beginner_mode: true,
        beginner_summary: "이 물건이 안전한지 한 눈에 확인하는 핵심 카드입니다."
      )
    ) { "x" }
    assert_text "이 물건이 안전한지 한 눈에 확인하는 핵심 카드입니다."
  end

  test "does not render beginner_summary when beginner_mode is false" do
    render_inline(
      ReportSectionComponent.new(
        number: 1,
        title: "종합 판정",
        anchor: "verdict",
        beginner_mode: false,
        beginner_summary: "이 물건이 안전한지 한 눈에 확인하는 핵심 카드입니다."
      )
    ) { "x" }
    assert_no_text "이 물건이 안전한지 한 눈에 확인하는 핵심 카드입니다."
  end

  test "does not render beginner_summary when beginner_mode is true but summary is nil" do
    render_inline(
      ReportSectionComponent.new(
        number: 1,
        title: "종합 판정",
        anchor: "verdict",
        beginner_mode: true,
        beginner_summary: nil
      )
    ) { "x" }
    # No summary line should be present; only the title and body content.
    assert_selector "h2", text: "종합 판정"
    assert_no_selector "p.beginner-summary"
  end
end
