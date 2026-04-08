require "test_helper"

class BudgetSettingTest < ActiveSupport::TestCase
  test "valid with user and available_cash" do
    bs = BudgetSetting.new(
      user: users(:guest), available_cash: 30000,
      property_type: property_types(:apartment),
      area_range_min: 59, area_range_max: 84,
      repair_cost: 500, acquisition_tax: 360, scrivener_fee: 80,
      moving_cost: 150, maintenance_fee: 50,
      loan_policy: loan_policies(:auction_bank_apartment), loan_ratio: 0.7,
      max_bid_amount: 85333,
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

  test "AREA_CATEGORIES has 5 categories with correct structure" do
    cats = BudgetSetting::AREA_CATEGORIES
    assert_equal 5, cats.length
    assert_equal :small, cats.first[:key]
    assert_equal 0, cats.first[:min_sqm]
    assert_equal 40, cats.first[:max_sqm]
    assert_equal :large, cats.last[:key]
    assert_equal 102, cats.last[:min_sqm]
    assert_equal 150, cats.last[:max_sqm]
  end

  test "area_min_options returns categories with min_sqm values" do
    options = BudgetSetting.area_min_options
    assert_equal 5, options.length
    assert_equal [ "소형 (10~15평 / ~40㎡)", 0 ], options.first
    assert_equal [ "대형 (45평~ / 102㎡~)", 102 ], options.last
  end

  test "area_max_options returns categories with max_sqm values" do
    options = BudgetSetting.area_max_options
    assert_equal 5, options.length
    assert_equal [ "소형 (10~15평 / ~40㎡)", 40 ], options.first
    assert_equal [ "대형 (45평~ / 102㎡~)", 150 ], options.last
  end

  test "invalid when area_range_min exceeds area_range_max" do
    bs = BudgetSetting.new(
      user: users(:guest), available_cash: 30000,
      area_range_min: 85, area_range_max: 40,
      failed_auction_rounds: 0
    )
    assert_not bs.valid?
    assert_includes bs.errors[:area_range_min], "은(는) 면적 최대 이하여야 합니다"
  end

  test "valid when area_range_min equals area_range_max" do
    bs = BudgetSetting.new(
      user: users(:guest), available_cash: 30000,
      area_range_min: 85, area_range_max: 85,
      failed_auction_rounds: 0
    )
    assert bs.valid?
  end
end
