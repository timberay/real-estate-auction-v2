require "test_helper"

class BudgetSettingTest < ActiveSupport::TestCase
  test "valid with user and available_cash" do
    bs = BudgetSetting.new(
      user: users(:guest), available_cash: 30000,
      property_type: property_types(:apartment),
      area_range_min: 59, area_range_max: 84,
      repair_cost: 500, acquisition_tax: 360, scrivener_fee: 80,
      moving_cost: 150, maintenance_fee: 50,
      loan_policy: loan_policies(:general_apartment), loan_ratio: 0.7,
      max_bid_amount: 85333, area_unit: "pyeong",
      failed_auction_rounds: 0, searchable_appraisal_limit: 85333
    )
    assert bs.valid?
  end

  test "invalid with duplicate user_id" do
    BudgetSetting.create!(
      user: users(:guest), available_cash: 30000, loan_ratio: 0.7,
      area_unit: "pyeong", failed_auction_rounds: 0
    )
    bs = BudgetSetting.new(user: users(:guest), available_cash: 20000)
    assert_not bs.valid?
    assert_includes bs.errors[:user_id], "has already been taken"
  end

  test "available_cash must be positive" do
    bs = BudgetSetting.new(user: users(:guest), available_cash: -100)
    assert_not bs.valid?
    assert_includes bs.errors[:available_cash], "must be greater than 0"
  end

  test "loan_ratio must be between 0 and 1" do
    bs = BudgetSetting.new(user: users(:guest), available_cash: 30000, loan_ratio: 1.5)
    assert_not bs.valid?
  end

  test "failed_auction_rounds must be 0-3" do
    bs = BudgetSetting.new(user: users(:guest), available_cash: 30000, failed_auction_rounds: 5)
    assert_not bs.valid?
  end

  test "area_unit must be pyeong or sqm" do
    bs = BudgetSetting.new(user: users(:guest), available_cash: 30000, area_unit: "invalid")
    assert_not bs.valid?
    assert_includes bs.errors[:area_unit], "is not included in the list"
  end

  test "completed? returns true when completed_at is set" do
    bs = BudgetSetting.new(completed_at: Time.current)
    assert bs.completed?
    bs = BudgetSetting.new(completed_at: nil)
    assert_not bs.completed?
  end

  test "total_reserves sums all reserve fund items" do
    bs = BudgetSetting.new(
      repair_cost: 500, acquisition_tax: 360, scrivener_fee: 80,
      moving_cost: 150, maintenance_fee: 50
    )
    assert_equal 1140, bs.total_reserves
  end
end
