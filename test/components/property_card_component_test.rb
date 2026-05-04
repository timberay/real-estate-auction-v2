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
    assert_selector ".inline-flex", text: "안전"
  end

  test "renders address" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_text property.address
  end

  test "renders appraisal price label and value on separate line" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_selector "[data-price-type='appraisal']", text: "8억"
    assert_text "감정가"
  end

  test "renders min bid price with label 최저매각가" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_selector "[data-price-type='min-bid']", text: "5억 6,000만원"
    assert_text "최저매각가"
  end

  test "renders budget exceeded badge when min_bid_price exceeds max_bid_amount" do
    property = properties(:safe_apartment) # min_bid_price: 560000000 (5.6억원)
    render_inline(PropertyCardComponent.new(property: property, max_bid_amount: 50000)) # 5억만원
    assert_selector ".inline-flex", text: "예산 초과"
  end

  test "does not render budget exceeded badge when within budget" do
    property = properties(:safe_apartment) # min_bid_price: 560000000 (5.6억원)
    render_inline(PropertyCardComponent.new(property: property, max_bid_amount: 100000)) # 10억만원
    assert_no_text "예산 초과"
  end

  test "does not render budget exceeded badge when min_bid_price within budget even if appraisal_price exceeds" do
    # Key behavior: a property with high appraisal but discounted min_bid (after 유찰) should NOT be flagged.
    property = properties(:safe_apartment) # appraisal_price: 8억, min_bid_price: 5.6억
    render_inline(PropertyCardComponent.new(property: property, max_bid_amount: 70000)) # 7억만원
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

  test "renders AI analysis badge when analyzed is true" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property, analyzed: true))
    assert_selector ".inline-flex", text: "AI 분석완료"
  end

  test "does not render AI analysis badge when analyzed is false" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property, analyzed: false))
    assert_no_text "AI 분석완료"
  end

  test "does not render AI analysis badge when analyzed is not provided" do
    property = properties(:safe_apartment)
    render_inline(PropertyCardComponent.new(property: property))
    assert_no_text "AI 분석완료"
  end
end
