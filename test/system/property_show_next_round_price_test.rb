require "application_system_test_case"

# T1.4(b) — property show 페이지에 "유찰 시 다음 회차 예정가" 가 표시되는지 확인.
# 산식: min_bid_price * 0.80, 만원 단위 절사.
class PropertyShowNextRoundPriceTest < ApplicationSystemTestCase
  setup do
    @user = users(:budget_user)
    sign_in_as(@user)

    # min_bid_price 350,000,000 * 0.8 = 280,000,000 = "2억 8,000만원"
    @property = Property.create!(
      case_number: "2026타경91040",
      court_name: "서울중앙지방법원",
      address: "서울특별시 종로구 청운동 99-1",
      appraisal_price: 500_000_000,
      min_bid_price: 350_000_000
    )
    UserProperty.find_or_create_by!(user: @user, property: @property)
    InspectionResult.create!(
      user: @user,
      property: @property,
      inspection_item: inspection_items(:rights_002),
      source_type: :manual,
      has_risk: false
    )
  end

  test "shows next-round expected price under 최저매각가" do
    visit property_path(@property)

    within "[data-property-detail='next-round-price']" do
      assert_text "유찰 시 다음 회차 예정가"
      assert_text "2억 8,000만원"
    end
  end

  test "hides next-round line when min_bid_price is zero" do
    # Skip validations to test the edge case (DB allows min_bid_price = 0)
    @property.update_columns(min_bid_price: 0)

    visit property_path(@property)

    assert_no_selector "[data-property-detail='next-round-price']"
  end

  test "next-round value matches Property#next_round_min_bid_price" do
    visit property_path(@property)
    assert_text format_price_won(@property.next_round_min_bid_price)
  end

  private

  # Inline copy of the helper so the system test doesn't depend on view helpers
  # being mixed into ActionDispatch::SystemTestCase.
  def format_price_won(amount)
    return "—" if amount.nil? || amount.zero?
    eok = amount / 100_000_000
    rest_man = (amount % 100_000_000) / 10_000
    if eok > 0 && rest_man > 0
      "#{eok}억 #{rest_man.to_s.reverse.scan(/\d{1,3}/).join(',').reverse}만원"
    elsif eok > 0
      "#{eok}억"
    else
      "#{(amount / 10_000).to_s.reverse.scan(/\d{1,3}/).join(',').reverse}만원"
    end
  end
end
