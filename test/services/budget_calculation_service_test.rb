require "test_helper"

class BudgetCalculationServiceTest < ActiveSupport::TestCase
  test "calculates max_bid_amount correctly" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
      loan_ratio: 0.7
    )

    # (30000 - 1140) / (1 - 0.7) = 28860 / 0.3 = 96200
    assert_equal 96200, result[:max_bid_amount]
    assert_equal 1140, result[:total_reserves]
  end

  test "calculates with zero loan ratio" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
      loan_ratio: 0.0
    )

    # (30000 - 1140) / (1 - 0) = 28860
    assert_equal 28860, result[:max_bid_amount]
  end

  test "returns breakdown with all reserve items" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
      loan_ratio: 0.7
    )

    assert_equal 500, result[:breakdown][:repair]
    assert_equal 360, result[:breakdown][:acquisition_tax]
    assert_equal 80, result[:breakdown][:scrivener]
    assert_equal 150, result[:breakdown][:moving]
    assert_equal 50, result[:breakdown][:maintenance]
    assert_equal 30000, result[:breakdown][:available_cash]
    assert_equal 0.7, result[:breakdown][:loan_ratio]
  end

  test "raises error when available_cash is less than reserves" do
    assert_raises(BudgetCalculationService::InsufficientFundsError) do
      BudgetCalculationService.call(
        available_cash: 500,
        reserve_funds: { repair: 500, acquisition_tax: 360, scrivener: 80, moving: 150, maintenance: 50 },
        loan_ratio: 0.7
      )
    end
  end

  test "handles missing reserve fund items as zero" do
    result = BudgetCalculationService.call(
      available_cash: 30000,
      reserve_funds: { repair: 500 },
      loan_ratio: 0.7
    )

    # (30000 - 500) / 0.3 = 98333
    assert_equal 98333, result[:max_bid_amount]
    assert_equal 500, result[:total_reserves]
  end
end
