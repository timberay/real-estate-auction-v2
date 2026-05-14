require "test_helper"

class TransferTaxCalculatorTest < ActiveSupport::TestCase
  def setup
    @apartment_id = property_types(:apartment).id
  end

  # --- .call ---

  test "homeless under_1y returns 70%" do
    result = TransferTaxCalculator.call(
      taxable_gain_manwon: 10_000,
      property_type_id: @apartment_id,
      household_tier: "homeless",
      holding_period: "under_1y",
      regulated_region: false
    )
    assert_in_delta 0.70, result.rate, 1e-6
    assert_equal 7000, result.tax_manwon
  end

  test "single_home over_2y returns 0% (1세대1주택 비과세 가정)" do
    result = TransferTaxCalculator.call(
      taxable_gain_manwon: 50_000,
      property_type_id: @apartment_id,
      household_tier: "single_home",
      holding_period: "over_2y",
      regulated_region: false
    )
    assert_in_delta 0.0, result.rate, 1e-6
    assert_equal 0, result.tax_manwon
  end

  test "multi_home_2 over_2y non-regulated returns 24% (한시 유예)" do
    result = TransferTaxCalculator.call(
      taxable_gain_manwon: 10_000,
      property_type_id: @apartment_id,
      household_tier: "multi_home_2",
      holding_period: "over_2y",
      regulated_region: false
    )
    assert_in_delta 0.24, result.rate, 1e-6
    assert_equal 2400, result.tax_manwon
  end

  test "multi_home_2 over_2y regulated returns 44% (중과)" do
    result = TransferTaxCalculator.call(
      taxable_gain_manwon: 10_000,
      property_type_id: @apartment_id,
      household_tier: "multi_home_2",
      holding_period: "over_2y",
      regulated_region: true
    )
    assert_in_delta 0.44, result.rate, 1e-6
    assert_equal 4400, result.tax_manwon
  end

  test "multi_home_3plus over_2y regulated returns 54% (중과 +30%p)" do
    result = TransferTaxCalculator.call(
      taxable_gain_manwon: 10_000,
      property_type_id: @apartment_id,
      household_tier: "multi_home_3plus",
      holding_period: "over_2y",
      regulated_region: true
    )
    assert_in_delta 0.54, result.rate, 1e-6
    assert_equal 5400, result.tax_manwon
  end

  test "homeless over_2y returns 6% (보수적 일반세율)" do
    result = TransferTaxCalculator.call(
      taxable_gain_manwon: 10_000,
      property_type_id: @apartment_id,
      household_tier: "homeless",
      holding_period: "over_2y",
      regulated_region: false
    )
    assert_in_delta 0.06, result.rate, 1e-6
    assert_equal 600, result.tax_manwon
  end

  test "btw_1_2y returns 60% regardless of tier" do
    %w[homeless single_home multi_home_2 multi_home_3plus].each do |tier|
      result = TransferTaxCalculator.call(
        taxable_gain_manwon: 10_000,
        property_type_id: @apartment_id,
        household_tier: tier,
        holding_period: "btw_1_2y",
        regulated_region: true
      )
      assert_in_delta 0.60, result.rate, 1e-6, "tier=#{tier} should be 60% in btw_1_2y"
    end
  end

  test "negative gain still returns the rate but tax_manwon clamps to 0" do
    result = TransferTaxCalculator.call(
      taxable_gain_manwon: -5_000,
      property_type_id: @apartment_id,
      household_tier: "homeless",
      holding_period: "under_1y",
      regulated_region: false
    )
    assert_in_delta 0.70, result.rate, 1e-6
    assert_equal 0, result.tax_manwon
  end

  test "raises RateNotFoundError when property_type has no rows" do
    stub_pt = PropertyType.create!(code: "stub_transfer_unused", name: "stub", enabled: false, sort_order: 99)
    assert_raises(TransferTaxCalculator::RateNotFoundError) do
      TransferTaxCalculator.call(
        taxable_gain_manwon: 10_000,
        property_type_id: stub_pt.id,
        household_tier: "homeless",
        holding_period: "under_1y",
        regulated_region: false
      )
    end
  end

  test "wildcard NULL row matches both regulated values for short-term holdings" do
    # under_1y rows have regulated_region: NULL → should match true and false both
    result_true = TransferTaxCalculator.call(
      taxable_gain_manwon: 10_000,
      property_type_id: @apartment_id,
      household_tier: "multi_home_2",
      holding_period: "under_1y",
      regulated_region: true
    )
    result_false = TransferTaxCalculator.call(
      taxable_gain_manwon: 10_000,
      property_type_id: @apartment_id,
      household_tier: "multi_home_2",
      holding_period: "under_1y",
      regulated_region: false
    )
    assert_in_delta 0.70, result_true.rate, 1e-6
    assert_in_delta 0.70, result_false.rate, 1e-6
  end

  # --- .matrix_for ---

  test "matrix_for returns nested hash keyed by tier and holding_period" do
    matrix = TransferTaxCalculator.matrix_for(
      property_type_id: @apartment_id,
      regulated_region: false
    )

    assert_in_delta 0.70, matrix["homeless"]["under_1y"], 1e-6
    assert_in_delta 0.60, matrix["homeless"]["btw_1_2y"], 1e-6
    assert_in_delta 0.06, matrix["homeless"]["over_2y"], 1e-6

    assert_in_delta 0.0, matrix["single_home"]["over_2y"], 1e-6
    assert_in_delta 0.24, matrix["multi_home_2"]["over_2y"], 1e-6
    assert_in_delta 0.24, matrix["multi_home_3plus"]["over_2y"], 1e-6
  end

  test "matrix_for differentiates regulated vs non-regulated for multi_home over_2y" do
    non_reg = TransferTaxCalculator.matrix_for(
      property_type_id: @apartment_id,
      regulated_region: false
    )
    reg = TransferTaxCalculator.matrix_for(
      property_type_id: @apartment_id,
      regulated_region: true
    )

    assert_in_delta 0.24, non_reg["multi_home_2"]["over_2y"], 1e-6
    assert_in_delta 0.44, reg["multi_home_2"]["over_2y"], 1e-6
    assert_in_delta 0.24, non_reg["multi_home_3plus"]["over_2y"], 1e-6
    assert_in_delta 0.54, reg["multi_home_3plus"]["over_2y"], 1e-6

    # under_1y / btw_1_2y are wildcard NULL → identical
    assert_in_delta non_reg["homeless"]["under_1y"], reg["homeless"]["under_1y"], 1e-6
  end

  test "matrix_for returns empty hash when property_type has no rows" do
    stub_pt = PropertyType.create!(code: "stub_transfer_matrix_empty", name: "stub", enabled: false, sort_order: 99)
    matrix = TransferTaxCalculator.matrix_for(
      property_type_id: stub_pt.id,
      regulated_region: false
    )
    assert_equal({}, matrix)
  end
end
