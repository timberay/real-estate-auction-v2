require "test_helper"

class TransferTaxRateTest < ActiveSupport::TestCase
  test "valid with required fields" do
    rate = TransferTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "homeless",
      holding_period: "under_1y",
      total_rate: 0.70
    )
    assert rate.valid?
  end

  test "household_tier must be in HOUSEHOLD_TIERS" do
    rate = TransferTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "invalid_tier",
      holding_period: "under_1y",
      total_rate: 0.70
    )
    assert_not rate.valid?
    assert_includes rate.errors[:household_tier], "은(는) 허용된 값이 아닙니다"
  end

  test "holding_period must be in HOLDING_PERIODS" do
    rate = TransferTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "homeless",
      holding_period: "weird",
      total_rate: 0.70
    )
    assert_not rate.valid?
    assert_includes rate.errors[:holding_period], "은(는) 허용된 값이 아닙니다"
  end

  test "total_rate must be present and within bounds" do
    rate = TransferTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "homeless",
      holding_period: "under_1y"
    )
    assert_not rate.valid?
    assert_includes rate.errors[:total_rate], "을(를) 입력해 주세요"
  end

  test "total_rate must not exceed 1.0" do
    rate = TransferTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "homeless",
      holding_period: "under_1y",
      total_rate: 1.5
    )
    assert_not rate.valid?
    assert_includes rate.errors[:total_rate], "은(는) 1 이하여야 합니다"
  end

  test "regulated_region is optional (nil = wildcard)" do
    rate = TransferTaxRate.new(
      property_type: property_types(:apartment),
      household_tier: "homeless",
      holding_period: "under_1y",
      regulated_region: nil,
      total_rate: 0.70
    )
    assert rate.valid?
  end

  test "HOUSEHOLD_TIERS mirrors AcquisitionTaxRate" do
    assert_equal AcquisitionTaxRate::HOUSEHOLD_TIERS, TransferTaxRate::HOUSEHOLD_TIERS
  end

  test "HOLDING_PERIODS lists three values" do
    assert_equal %w[under_1y btw_1_2y over_2y], TransferTaxRate::HOLDING_PERIODS
  end
end
