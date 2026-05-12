require "test_helper"

class AcquisitionTaxRateTest < ActiveSupport::TestCase
  test "valid with required fields" do
    rate = AcquisitionTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "homeless",
      price_bucket_min_manwon: 0,
      price_bucket_max_manwon: 60000,
      area_over_85: false,
      total_rate: 0.011
    )
    assert rate.valid?
  end

  test "household_tier must be in HOUSEHOLD_TIERS" do
    rate = AcquisitionTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "invalid_tier",
      price_bucket_min_manwon: 0,
      total_rate: 0.011
    )
    assert_not rate.valid?
    assert_includes rate.errors[:household_tier], "은(는) 허용된 값이 아닙니다"
  end

  test "total_rate must be present and within bounds" do
    rate = AcquisitionTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "homeless",
      price_bucket_min_manwon: 0
    )
    assert_not rate.valid?
    assert_includes rate.errors[:total_rate], "을(를) 입력해 주세요"
  end

  test "HOUSEHOLD_TIERS constant lists all four tiers" do
    assert_equal %w[homeless single_home multi_home_2 multi_home_3plus],
                 AcquisitionTaxRate::HOUSEHOLD_TIERS
  end
end
