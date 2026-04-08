require "test_helper"

class OnboardingsControllerTest < ActionDispatch::IntegrationTest
  test "GET step1 renders the first step" do
    get start_onboarding_url
    assert_response :success
    assert_select "turbo-frame#onboarding_wizard"
  end

  test "POST step1 saves available_cash and renders step2" do
    get start_onboarding_url  # create guest session

    post step1_onboarding_url, params: { budget_setting: { available_cash: 30000 } }
    assert_response :success
    assert_select "turbo-frame#onboarding_wizard"

    user = User.find_by(email: "guest@auction.local")
    assert_equal 30000, user.budget_setting.available_cash
  end

  test "POST step1 with invalid data re-renders step1" do
    get start_onboarding_url

    post step1_onboarding_url, params: { budget_setting: { available_cash: -100 } }
    assert_response :unprocessable_entity
  end

  test "POST step2 saves reserve funds and renders step3" do
    get start_onboarding_url
    post step1_onboarding_url, params: { budget_setting: { available_cash: 30000 } }

    apt = property_types(:apartment)
    post step2_onboarding_url, params: {
      budget_setting: {
        property_type_id: apt.id,
        area_categories: %w[mid_small mid],
        repair_cost: 500,
        acquisition_tax: 360,
        scrivener_fee: 80,
        moving_cost: 150,
        maintenance_fee: 50
      }
    }
    assert_response :success

    user = User.find_by(email: "guest@auction.local")
    assert_equal apt.id, user.budget_setting.property_type_id
    assert_equal 500, user.budget_setting.repair_cost
    assert_equal 40, user.budget_setting.area_range_min
    assert_equal 85, user.budget_setting.area_range_max
  end

  test "POST step3 calculates max bid, creates snapshot, and redirects to complete" do
    get start_onboarding_url
    post step1_onboarding_url, params: { budget_setting: { available_cash: 30000 } }

    apt = property_types(:apartment)
    policy = loan_policies(:auction_bank_apartment)
    post step2_onboarding_url, params: {
      budget_setting: {
        property_type_id: apt.id, area_categories: %w[mid_small mid],
        repair_cost: 500, acquisition_tax: 360,
        scrivener_fee: 80, moving_cost: 150, maintenance_fee: 50
      }
    }

    post step3_onboarding_url, params: {
      budget_setting: {
        loan_policy_id: policy.id,
        loan_ratio: 0.7,
        failed_auction_rounds: 2
      }
    }
    assert_redirected_to complete_onboarding_url

    user = User.find_by(email: "guest@auction.local")
    setting = user.budget_setting
    assert setting.completed?
    assert_equal 96200, setting.max_bid_amount
    assert_equal 1, user.budget_snapshots.count
  end

  test "GET step1 renders budget summary in uncalculated state for new user" do
    get start_onboarding_url
    assert_response :success
    # Summary grid is rendered with dashed border (uncalculated)
    assert_select "div[class*='border-dashed']"
    assert_select "div[class*='grid-cols-2']"
  end

  test "GET step1 renders budget summary with values for returning user" do
    # First complete onboarding to establish a calculated setting
    get start_onboarding_url
    guest = User.find_by(email: "guest@auction.local")
    apt = property_types(:apartment)
    policy = loan_policies(:auction_bank_apartment)

    BudgetSetting.create!(
      user: guest, available_cash: 30000, property_type: apt,
      loan_policy: policy, loan_ratio: 0.7, failed_auction_rounds: 0,
      repair_cost: 500, acquisition_tax: 360, scrivener_fee: 80,
      moving_cost: 150, maintenance_fee: 50,
      max_bid_amount: 96200, searchable_appraisal_limit: 96200,
      completed_at: Time.current
    )

    get start_onboarding_url
    assert_response :success
    # Summary grid is rendered with solid border (calculated)
    assert_select "div[class*='bg-blue-50']"
    assert_select "div[class*='border-blue-200']"
  end

  test "GET complete shows results" do
    get start_onboarding_url
    guest = User.find_by(email: "guest@auction.local")
    BudgetSetting.create!(
      user: guest, available_cash: 30000, loan_ratio: 0.7,
      max_bid_amount: 96200,
      failed_auction_rounds: 0, searchable_appraisal_limit: 96200,
      completed_at: Time.current
    )
    BudgetSnapshot.create!(
      user: guest, version: 1, trigger: "onboarding",
      available_cash: 30000, max_bid_amount: 96200,
      calculated_at: Time.current
    )

    get complete_onboarding_url
    assert_response :success
  end
end
