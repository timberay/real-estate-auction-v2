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
      max_bid_amount: 85333
    )
    assert bs.valid?
  end

  test "invalid with duplicate user_id" do
    BudgetSetting.create!(
      user: users(:guest), available_cash: 30000, loan_ratio: 0.7
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
    assert_equal "small", cats.first[:key]
    assert_equal 0, cats.first[:min_sqm]
    assert_equal 40, cats.first[:max_sqm]
    assert_equal "large", cats.last[:key]
    assert_equal 102, cats.last[:min_sqm]
    assert_equal 150, cats.last[:max_sqm]
  end

  test "area_category_options returns label-key pairs" do
    options = BudgetSetting.area_category_options
    assert_equal 5, options.length
    assert_equal [ "소형 (10~15평 / ~40㎡)", "small" ], options.first
  end

  test "area_range_for returns min and max for a category key" do
    range = BudgetSetting.area_range_for("mid")
    assert_equal 60, range[:min]
    assert_equal 85, range[:max]
  end

  test "area_range_for returns empty hash for unknown key" do
    assert_equal({}, BudgetSetting.area_range_for("unknown"))
  end

  test "selected_area_category derives key from stored min/max" do
    bs = BudgetSetting.new(area_range_min: 60, area_range_max: 85)
    assert_equal "mid", bs.selected_area_category
  end

  test "negative reserve fields are rejected" do
    BudgetSetting::RESERVE_FIELDS.each do |field|
      bs = BudgetSetting.new(user: users(:guest), available_cash: 30000, field => -100)
      assert_not bs.valid?, "expected #{field} = -100 to be invalid"
      assert_includes bs.errors[field], "must be greater than or equal to 0"
    end
  end

  test "zero reserve fields are accepted" do
    bs = BudgetSetting.new(
      user: users(:guest), available_cash: 30000,
      repair_cost: 0, acquisition_tax: 0, scrivener_fee: 0,
      moving_cost: 0, maintenance_fee: 0
    )
    bs.valid?
    BudgetSetting::RESERVE_FIELDS.each do |field|
      assert_empty bs.errors[field], "expected #{field} = 0 to have no errors"
    end
  end

  test "mid category label does not contain 국평" do
    mid = BudgetSetting::AREA_CATEGORIES.find { |c| c[:key] == "mid" }
    assert_equal "중형 (30~34평 / 60~85㎡)", mid[:label]
  end
end
