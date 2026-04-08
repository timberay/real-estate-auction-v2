require "test_helper"

class Settings::BudgetSnapshotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_url
    @user = User.find_by(email: "guest@auction.local")
    BudgetSetting.create!(
      user: @user, available_cash: 30000, loan_ratio: 0.7,
      max_bid_amount: 96200,
      completed_at: Time.current
    )
    @snapshot1 = BudgetSnapshot.create!(
      user: @user, version: 1, trigger: "onboarding",
      available_cash: 30000, loan_ratio: 0.7, max_bid_amount: 96200,
      calculated_at: 1.day.ago
    )
    @snapshot2 = BudgetSnapshot.create!(
      user: @user, version: 2, trigger: "manual_edit",
      available_cash: 40000, loan_ratio: 0.7, max_bid_amount: 129533,
      calculated_at: Time.current
    )
  end

  test "GET index lists snapshots" do
    get settings_budget_snapshots_url
    assert_response :success
  end

  test "GET show displays a single snapshot" do
    get settings_budget_snapshot_url(@snapshot1)
    assert_response :success
  end

  test "GET compare shows diff between two snapshots" do
    get compare_settings_budget_snapshots_url(ids: [ @snapshot1.id, @snapshot2.id ])
    assert_response :success
  end

  test "POST recalculate creates a new snapshot" do
    assert_difference "@user.budget_snapshots.count", 1 do
      post recalculate_settings_budget_snapshot_url(@snapshot1)
    end
    assert_redirected_to settings_budget_snapshots_url
  end
end
