require "test_helper"

class BudgetSnapshotServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @setting = BudgetSetting.create!(
      user: @user,
      available_cash: 30000,
      property_type: property_types(:apartment),
      area_range_min: 59,
      area_range_max: 84,
      repair_cost: 500,
      acquisition_tax: 360,
      scrivener_fee: 80,
      moving_cost: 150,
      maintenance_fee: 50,
      loan_policy: loan_policies(:auction_bank_apartment),
      loan_ratio: 0.7,
      max_bid_amount: 96200,
      area_unit: "pyeong",
      failed_auction_rounds: 0,
      searchable_appraisal_limit: 96200,
      completed_at: Time.current
    )
  end

  test "create builds snapshot from current budget_settings" do
    snapshot = BudgetSnapshotService.create(user: @user, trigger: "onboarding")

    assert_equal 1, snapshot.version
    assert_equal "onboarding", snapshot.trigger
    assert_equal 30000, snapshot.available_cash
    assert_equal "아파트", snapshot.property_type_name
    assert_equal "59~84㎡", snapshot.area_range
    assert_equal 0.7, snapshot.loan_ratio.to_f
    assert_equal "경락대출 (1금융)", snapshot.loan_policy_name
    assert_equal 96200, snapshot.max_bid_amount
    assert_nil snapshot.parent_snapshot_id
    assert snapshot.calculated_at.present?
  end

  test "create increments version for same user" do
    s1 = BudgetSnapshotService.create(user: @user, trigger: "onboarding")
    s2 = BudgetSnapshotService.create(user: @user, trigger: "manual_edit")

    assert_equal 1, s1.version
    assert_equal 2, s2.version
  end

  test "recalculate creates new snapshot with parent reference" do
    original = BudgetSnapshotService.create(user: @user, trigger: "onboarding")

    # Change the live settings
    @setting.update!(loan_ratio: 0.6, max_bid_amount: 72150, searchable_appraisal_limit: 72150)

    recalculated = BudgetSnapshotService.recalculate(user: @user, parent_snapshot: original)

    assert_equal 2, recalculated.version
    assert_equal "recalculate", recalculated.trigger
    assert_equal original.id, recalculated.parent_snapshot_id
    assert_equal 0.6, recalculated.loan_ratio.to_f
    assert_equal 72150, recalculated.max_bid_amount
  end

  test "compare returns diff between two snapshots" do
    s1 = BudgetSnapshotService.create(user: @user, trigger: "onboarding")

    @setting.update!(loan_ratio: 0.6, max_bid_amount: 72150, searchable_appraisal_limit: 72150)
    s2 = BudgetSnapshotService.create(user: @user, trigger: "manual_edit")

    diff = BudgetSnapshotService.compare(snapshot_a: s1, snapshot_b: s2)

    assert_equal({ was: 0.7, now: 0.6 }, diff[:loan_ratio])
    assert_equal({ was: 96200, now: 72150, delta: -24050 }, diff[:max_bid_amount])
  end

  test "compare returns empty hash when snapshots are identical" do
    s1 = BudgetSnapshotService.create(user: @user, trigger: "onboarding")
    s2 = BudgetSnapshotService.create(user: @user, trigger: "manual_edit")

    diff = BudgetSnapshotService.compare(snapshot_a: s1, snapshot_b: s2)
    assert_empty diff
  end
end
