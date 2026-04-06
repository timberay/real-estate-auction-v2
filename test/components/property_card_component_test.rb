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

  test "renders budget exceeded badge when appraisal_price exceeds max_bid_amount" do
    property = properties(:safe_apartment) # appraisal_price: 80000
    render_inline(PropertyCardComponent.new(property: property, max_bid_amount: 50000))
    assert_selector ".inline-flex", text: "예산 초과"
  end

  test "does not render budget exceeded badge when within budget" do
    property = properties(:safe_apartment) # appraisal_price: 80000
    render_inline(PropertyCardComponent.new(property: property, max_bid_amount: 100000))
    assert_no_text "예산 초과"
  end

  test "does not render budget exceeded badge when max_bid_amount is nil" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property, max_bid_amount: nil))
    assert_no_text "예산 초과"
  end

  test "does not render budget exceeded badge when max_bid_amount not provided" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_no_text "예산 초과"
  end
end
