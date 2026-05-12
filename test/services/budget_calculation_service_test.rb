require "test_helper"

class BudgetCalculationServiceTest < ActiveSupport::TestCase
  # Single-bucket housing brackets: 6억↓ 1.1%, 6~9억 2.2%, 9억+ 3.3%
  HOUSING_BRACKETS = [
    { rate: 0.011, max: 60_000 },
    { rate: 0.022, max: 90_000 },
    { rate: 0.033, max: nil }
  ].freeze

  test "small-cash scenario picks lowest bracket and yields large bid" do
    result = BudgetCalculationService.call(
      available_cash: 3_000,
      reserves_excluding_acquisition_tax: { repair: 400, scrivener: 60, moving: 100, maintenance: 40 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS
    )

    # R = 600; t1 = 0.011 → B = floor((3000-600)/(0.3+0.011)) = floor(2400/0.311) = 7717
    assert_equal 7717, result[:max_bid_amount]
    assert_equal 85, result[:acquisition_tax]
    assert_in_delta 0.011, result[:acquisition_tax_rate], 1e-6
  end

  test "mid-cash scenario falls through to bracket 2" do
    result = BudgetCalculationService.call(
      available_cash: 30_000,
      reserves_excluding_acquisition_tax: { repair: 800, scrivener: 200, moving: 300, maintenance: 200 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS
    )

    # R = 1500; t1 candidate = floor(28500/0.311) = 91640 > 60000 → t2 candidate = floor(28500/0.322) = 88509
    assert_equal 88_509, result[:max_bid_amount]
    assert_equal 1947, result[:acquisition_tax]
    assert_in_delta 0.022, result[:acquisition_tax_rate], 1e-6
  end

  test "large-cash scenario falls through to bracket 3" do
    result = BudgetCalculationService.call(
      available_cash: 100_000,
      reserves_excluding_acquisition_tax: { repair: 1000, scrivener: 300, moving: 500, maintenance: 200 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS
    )

    # R = 2000; iterates past brackets 1 & 2 → t3 candidate = floor(98000/0.333) = 294294
    assert_equal 294_294, result[:max_bid_amount]
    assert_equal 9712, result[:acquisition_tax]
    assert_in_delta 0.033, result[:acquisition_tax_rate], 1e-6
  end

  test "override mode uses the supplied tax and ignores brackets" do
    result = BudgetCalculationService.call(
      available_cash: 3_000,
      reserves_excluding_acquisition_tax: { repair: 400, scrivener: 60, moving: 100, maintenance: 40 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS,
      acquisition_tax_override: 800
    )

    # B = floor((3000-600-800)/0.3) = floor(1600/0.3) = 5333
    assert_equal 5333, result[:max_bid_amount]
    assert_equal 800, result[:acquisition_tax]
    assert_nil result[:acquisition_tax_rate]
  end

  test "insufficient cash raises InsufficientFundsError" do
    assert_raises(BudgetCalculationService::InsufficientFundsError) do
      BudgetCalculationService.call(
        available_cash: 500,
        reserves_excluding_acquisition_tax: { repair: 400, scrivener: 60, moving: 100, maintenance: 40 },
        loan_ratio: 0.7,
        tax_brackets: HOUSING_BRACKETS
      )
    end
  end

  test "empty tax_brackets in auto mode raises ArgumentError" do
    assert_raises(ArgumentError) do
      BudgetCalculationService.call(
        available_cash: 3_000,
        reserves_excluding_acquisition_tax: { repair: 400, scrivener: 60, moving: 100, maintenance: 40 },
        loan_ratio: 0.7,
        tax_brackets: []
      )
    end
  end

  test "missing reserve items default to zero" do
    result = BudgetCalculationService.call(
      available_cash: 30_000,
      reserves_excluding_acquisition_tax: { repair: 500 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS
    )

    # R = 500; t1 candidate = floor(29500/0.311) = 94855 > 60000 → t2 = floor(29500/0.322) = 91614 > 90000 → t3 = floor(29500/0.333) = 88588
    assert_equal 88_588, result[:max_bid_amount]
    assert_in_delta 0.033, result[:acquisition_tax_rate], 1e-6
  end

  test "breakdown includes all inputs and computed values" do
    result = BudgetCalculationService.call(
      available_cash: 3_000,
      reserves_excluding_acquisition_tax: { repair: 400, scrivener: 60, moving: 100, maintenance: 40 },
      loan_ratio: 0.7,
      tax_brackets: HOUSING_BRACKETS
    )

    assert_equal 3_000, result[:breakdown][:available_cash]
    assert_equal 400, result[:breakdown][:repair]
    assert_equal 60, result[:breakdown][:scrivener]
    assert_equal 100, result[:breakdown][:moving]
    assert_equal 40, result[:breakdown][:maintenance]
    assert_equal 85, result[:breakdown][:acquisition_tax]
    assert_equal 0.7, result[:breakdown][:loan_ratio]
    assert_equal 685, result[:total_reserves]
  end
end
