require "test_helper"

class Settings::BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_url  # create guest session
    @user = User.find_by(email: "guest@auction.local")
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
      failed_auction_rounds: 0,
      searchable_appraisal_limit: 96200,
      completed_at: Time.current
    )
  end

  test "GET show renders budget settings" do
    get settings_budget_url
    assert_response :success
  end

  test "PATCH update saves new settings and creates snapshot" do
    patch settings_budget_url, params: {
      budget_setting: {
        available_cash: 40000,
        property_type_id: property_types(:apartment).id,
        area_categories: %w[mid_small mid],
        repair_cost: 500,
        acquisition_tax: 360,
        scrivener_fee: 80,
        moving_cost: 150,
        maintenance_fee: 50,
        loan_policy_id: loan_policies(:auction_bank_apartment).id,
        loan_ratio: 0.7,
        failed_auction_rounds: 0
      }
    }

    assert_redirected_to settings_budget_url
    @setting.reload
    assert_equal 40000, @setting.available_cash
    assert_equal 1, @user.budget_snapshots.count
  end
end
