require "test_helper"

class AcquisitionTaxCalculatorTest < ActiveSupport::TestCase
  def setup
    @apartment_id = property_types(:apartment).id
    @officetel_id = property_types(:officetel).id
  end

  test "homeless under 6억 under 85㎡ returns 1.1%" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 50_000,
      property_type_id: @apartment_id,
      household_tier: "homeless",
      regulated_region: false,
      area_over_85: false
    )
    assert_in_delta 0.011, result.rate, 1e-6
    assert_equal 550, result.tax_manwon
  end

  test "homeless 6~9억 under 85㎡ returns 2.2%" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 70_000,
      property_type_id: @apartment_id,
      household_tier: "homeless",
      regulated_region: false,
      area_over_85: false
    )
    assert_in_delta 0.022, result.rate, 1e-6
    assert_equal 1540, result.tax_manwon
  end

  test "homeless 9억+ over 85㎡ returns 3.5%" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 95_000,
      property_type_id: @apartment_id,
      household_tier: "homeless",
      regulated_region: false,
      area_over_85: true
    )
    assert_in_delta 0.035, result.rate, 1e-6
    assert_equal 3325, result.tax_manwon
  end

  test "multi_home_2 regulated region returns 8.4% regardless of bracket" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 40_000,
      property_type_id: @apartment_id,
      household_tier: "multi_home_2",
      regulated_region: true,
      area_over_85: false
    )
    assert_in_delta 0.084, result.rate, 1e-6
    assert_equal 3360, result.tax_manwon
  end

  test "multi_home_3plus regulated returns 12.4%" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 50_000,
      property_type_id: @apartment_id,
      household_tier: "multi_home_3plus",
      regulated_region: true,
      area_over_85: false
    )
    assert_in_delta 0.124, result.rate, 1e-6
    assert_equal 6200, result.tax_manwon
  end

  test "officetel returns 4.6% regardless of inputs" do
    result = AcquisitionTaxCalculator.call(
      bid_manwon: 100_000,
      property_type_id: @officetel_id,
      household_tier: "homeless",
      regulated_region: false,
      area_over_85: nil
    )
    assert_in_delta 0.046, result.rate, 1e-6
    assert_equal 4600, result.tax_manwon
  end

  test "raises RateNotFoundError when property_type has no rows" do
    stub_pt = PropertyType.create!(code: "stub_unused", name: "stub", enabled: false, sort_order: 99)
    assert_raises(AcquisitionTaxCalculator::RateNotFoundError) do
      AcquisitionTaxCalculator.call(
        bid_manwon: 50_000,
        property_type_id: stub_pt.id,
        household_tier: "homeless",
        regulated_region: false,
        area_over_85: false
      )
    end
  end
end
