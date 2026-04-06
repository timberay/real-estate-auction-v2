require "test_helper"

class RightsAnalysis::AssumedAmountCalculatorTest < ActiveSupport::TestCase
  test "opposing power tenant without dividend request is assumed" do
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: false, confirmed_date: "2024-03-05", is_small_sum_tenant: false }
    ]
    result = RightsAnalysis::AssumedAmountCalculator.call(tenants)
    assert_equal 50_000_000, result[:assumed_amount]
    assert_equal 50_000_000, result[:total_risk_amount]
  end

  test "opposing power tenant with dividend request is not assumed" do
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: true, confirmed_date: "2024-03-05", is_small_sum_tenant: false }
    ]
    result = RightsAnalysis::AssumedAmountCalculator.call(tenants)
    assert_equal 0, result[:assumed_amount]
    assert_equal 0, result[:total_risk_amount]
  end

  test "non-opposing power tenant is never assumed" do
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: false,
        dividend_requested: false, confirmed_date: "2024-03-05", is_small_sum_tenant: false }
    ]
    result = RightsAnalysis::AssumedAmountCalculator.call(tenants)
    assert_equal 0, result[:assumed_amount]
  end

  test "opposing power without confirmed date adds to risk amount" do
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: true, confirmed_date: nil, is_small_sum_tenant: false }
    ]
    result = RightsAnalysis::AssumedAmountCalculator.call(tenants)
    assert_equal 0, result[:assumed_amount]
    assert_equal 50_000_000, result[:total_risk_amount]
  end

  test "sums multiple assumed tenants" do
    tenants = [
      { name: "임차인A", deposit: 30_000_000, has_opposing_power: true,
        dividend_requested: false, confirmed_date: nil, is_small_sum_tenant: false },
      { name: "임차인B", deposit: 20_000_000, has_opposing_power: true,
        dividend_requested: false, confirmed_date: nil, is_small_sum_tenant: false }
    ]
    result = RightsAnalysis::AssumedAmountCalculator.call(tenants)
    assert_equal 50_000_000, result[:assumed_amount]
  end

  test "empty tenants returns zero" do
    result = RightsAnalysis::AssumedAmountCalculator.call([])
    assert_equal 0, result[:assumed_amount]
    assert_equal 0, result[:total_risk_amount]
  end
end
