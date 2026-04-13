# frozen_string_literal: true

require "test_helper"

class PropertyInfoComponentTest < ViewComponent::TestCase
  test "renders case number" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "2026타경10001"
  end

  test "renders address" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "서울특별시 강남구 역삼동 100-1"
  end

  test "renders property type" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "아파트"
  end

  test "renders appraisal price formatted" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "8억"
  end

  test "renders min bid price formatted" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "5억 6,000만원"
  end

  test "renders exclusive area" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "84.5㎡"
  end

  test "renders failed bid count" do
    property = properties(:risky_villa)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "2회"
  end

  test "renders dash for missing claim amount" do
    property = properties(:safe_apartment)
    render_inline(PropertyInfoComponent.new(property: property))
    assert_text "—"
  end
end
