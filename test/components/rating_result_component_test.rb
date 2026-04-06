# frozen_string_literal: true

require "test_helper"

class RatingResultComponentTest < ViewComponent::TestCase
  test "renders safe rating" do
    property = properties(:safe_apartment)
    render_inline(RatingResultComponent.new(property: property, risk_results: [], rating: :safe))
    assert_text "안전"
    assert_text "위험 항목이 없습니다"
  end

  test "renders danger rating" do
    property = properties(:risky_villa)
    result = property_check_results(:risky_villa_rights_011)
    render_inline(RatingResultComponent.new(property: property, risk_results: [ result ], rating: :danger))
    assert_text "경고"
  end

  test "renders optional label" do
    property = properties(:safe_apartment)
    render_inline(RatingResultComponent.new(property: property, risk_results: [], rating: :safe, label: "체크리스트 등급"))
    assert_text "체크리스트 등급"
  end
end
