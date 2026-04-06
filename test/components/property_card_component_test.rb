# frozen_string_literal: true

require "test_helper"

class PropertyCardComponentTest < ViewComponent::TestCase
  test "renders property case number" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_text property.case_number
  end

  test "renders safety badge" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property, safety_rating: "safe"))
    assert_selector ".inline-flex", text: "Safe"
  end

  test "renders address" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_text property.address
  end

  test "renders appraisal price label and value on separate line" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_selector "[data-price-type='appraisal']", text: "80,000만원"
    assert_text "감정가"
  end

  test "renders min bid price with label 최저매각가" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_selector "[data-price-type='min-bid']", text: "56,000만원"
    assert_text "최저매각가"
  end
end
