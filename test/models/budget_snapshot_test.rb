require "test_helper"

class BudgetSnapshotTest < ActiveSupport::TestCase
  test "valid with required fields" do
    snapshot = BudgetSnapshot.new(
      user: users(:guest), version: 1, trigger: "onboarding",
      available_cash: 30000, property_type_name: "아파트",
      area_range: "59~84㎡", area_unit: "pyeong",
      repair_cost: 500, acquisition_tax: 360, scrivener_fee: 80,
      moving_cost: 150, maintenance_fee: 50,
      loan_policy_name: "일반 주담대", loan_ratio: 0.7,
      max_bid_amount: 85333, failed_auction_rounds: 0,
      searchable_appraisal_limit: 85333, calculated_at: Time.current
    )
    assert snapshot.valid?
  end

  test "invalid without trigger" do
    snapshot = BudgetSnapshot.new(user: users(:guest), version: 1, trigger: nil, calculated_at: Time.current)
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:trigger], "is not included in the list"
  end

  test "trigger must be one of allowed values" do
    snapshot = BudgetSnapshot.new(user: users(:guest), version: 1, trigger: "invalid", calculated_at: Time.current)
    assert_not snapshot.valid?
    assert_includes snapshot.errors[:trigger], "is not included in the list"
  end

  test "parent_snapshot association is optional" do
    snapshot = BudgetSnapshot.new(
      user: users(:guest), version: 1, trigger: "onboarding",
      calculated_at: Time.current, parent_snapshot: nil
    )
    assert snapshot.valid?
  end

  test "next_version_for returns 1 for first snapshot" do
    assert_equal 1, BudgetSnapshot.next_version_for(users(:guest).id)
  end

  test "next_version_for returns max + 1 for existing snapshots" do
    BudgetSnapshot.create!(
      user: users(:guest), version: 1, trigger: "onboarding",
      calculated_at: Time.current
    )
    assert_equal 2, BudgetSnapshot.next_version_for(users(:guest).id)
  end
end
