# frozen_string_literal: true

require "test_helper"

class RatingResultComponentTest < ViewComponent::TestCase
  test "renders safe rating" do
    property = properties(:safe_apartment)
    render_inline(RatingResultComponent.new(property: property, risk_results: [], rating: "safe"))
    assert_text "Safe"
    assert_text "위험 항목이 없습니다"
  end

  test "renders danger rating with risk items" do
    property = properties(:risky_villa)
    result = property_check_results(:risky_villa_rights_011)
    render_inline(RatingResultComponent.new(property: property, risk_results: [ result ], rating: "danger"))
    assert_text "Danger"
    assert_selector "details"
  end
end
