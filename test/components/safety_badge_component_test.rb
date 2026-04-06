# frozen_string_literal: true

require "test_helper"

class SafetyBadgeComponentTest < ViewComponent::TestCase
  test "renders safe badge in Korean" do
    render_inline(SafetyBadgeComponent.new(rating: "safe"))
    assert_selector ".inline-flex", text: "안전"
  end

  test "renders caution badge in Korean" do
    render_inline(SafetyBadgeComponent.new(rating: "caution"))
    assert_selector ".inline-flex", text: "주의"
  end

  test "renders danger badge in Korean" do
    render_inline(SafetyBadgeComponent.new(rating: "danger"))
    assert_selector ".inline-flex", text: "경고"
  end

  test "renders unanalyzed badge for nil rating" do
    render_inline(SafetyBadgeComponent.new(rating: nil))
    assert_selector ".inline-flex", text: "미분석"
  end
end
