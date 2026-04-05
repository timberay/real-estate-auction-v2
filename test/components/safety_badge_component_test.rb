# frozen_string_literal: true

require "test_helper"

class SafetyBadgeComponentTest < ViewComponent::TestCase
  test "renders safe badge" do
    render_inline(SafetyBadgeComponent.new(rating: "safe"))
    assert_selector ".inline-flex", text: "Safe"
  end

  test "renders caution badge" do
    render_inline(SafetyBadgeComponent.new(rating: "caution"))
    assert_selector ".inline-flex", text: "Caution"
  end

  test "renders danger badge" do
    render_inline(SafetyBadgeComponent.new(rating: "danger"))
    assert_selector ".inline-flex", text: "Danger"
  end

  test "renders unanalyzed badge for nil rating" do
    render_inline(SafetyBadgeComponent.new(rating: nil))
    assert_selector ".inline-flex", text: "미분석"
  end
end
