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

    user = User.find(session[:user_id])
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
        area_category: "mid",
        repair_cost: 500,
        acquisition_tax: 360,
        scrivener_fee: 80,
        moving_cost: 150,
        maintenance_fee: 50
      }
    }
    assert_response :success

    user = User.find(session[:user_id])
    assert_equal apt.id, user.budget_setting.property_type_id
    assert_equal 500, user.budget_setting.repair_cost
    assert_equal 60, user.budget_setting.area_range_min
    assert_equal 85, user.budget_setting.area_range_max
  end

  test "POST step3 calculates max bid, creates snapshot, and redirects to complete" do
    get start_onboarding_url
    post step1_onboarding_url, params: { budget_setting: { available_cash: 30000 } }

    apt = property_types(:apartment)
    policy = loan_policies(:auction_bank_apartment)
    post step2_onboarding_url, params: {
      budget_setting: {
        property_type_id: apt.id, area_category: "mid",
        repair_cost: 500, acquisition_tax: 360,
        scrivener_fee: 80, moving_cost: 150, maintenance_fee: 50
      }
    }

    post step3_onboarding_url, params: {
      budget_setting: {
        loan_policy_id: policy.id,
        loan_ratio: 0.7
      }
    }
    assert_redirected_to complete_onboarding_url

    user = User.find(session[:user_id])
    setting = user.budget_setting
    assert setting.completed?
    assert_equal 96200, setting.max_bid_amount
  end

  test "GET step1 renders budget summary in uncalculated state for new user" do
    get start_onboarding_url
    assert_response :success
    # Summary grid is rendered with dashed border (uncalculated)
    assert_select "div[class*='border-dashed']"
    assert_select "div[class*='grid-cols-2']"
  end

  test "POST step1 saves region along with available_cash" do
    get start_onboarding_url

    post step1_onboarding_url, params: {
      budget_setting: { available_cash: 30000, region: "서울특별시" }
    }
    assert_response :success

    user = User.find(session[:user_id])
    assert_equal "서울특별시", user.budget_setting.region
  end

  test "GET step1 redirects to budget settings for returning user" do
    get start_onboarding_url
    guest = User.find(session[:user_id])
    apt = property_types(:apartment)
    policy = loan_policies(:auction_bank_apartment)

    BudgetSetting.create!(
      user: guest, available_cash: 30000, property_type: apt,
      loan_policy: policy, loan_ratio: 0.7,
      repair_cost: 500, acquisition_tax: 360, scrivener_fee: 80,
      moving_cost: 150, maintenance_fee: 50,
      max_bid_amount: 96200,
      completed_at: Time.current
    )

    get start_onboarding_url
    assert_redirected_to settings_budget_url
  end

  test "step3 renders regulated LTV when region is Seoul" do
    get start_onboarding_url
    post step1_onboarding_url, params: { budget_setting: { available_cash: 30000, region: "서울특별시" } }

    apt = property_types(:apartment)
    post step2_onboarding_url, params: {
      budget_setting: {
        property_type_id: apt.id, area_category: "mid",
        repair_cost: 500, acquisition_tax: 360,
        scrivener_fee: 80, moving_cost: 150, maintenance_fee: 50
      }
    }
    assert_response :success
    # The radio input itself carries the region-appropriate ratio
    assert_select "input[type='radio'][name='budget_setting[loan_policy_id]'][data-loan-ratio='0.4']"
    # And the visible LTV span next to the radio name shows the regulated rate
    assert_select "span.font-medium", text: "경락대출 (1금융)"
    assert_select "input[type='range'][value='40']"
  end

  test "step3 renders non-regulated LTV when region is not Seoul" do
    get start_onboarding_url
    post step1_onboarding_url, params: { budget_setting: { available_cash: 30000, region: "경기도" } }

    apt = property_types(:apartment)
    post step2_onboarding_url, params: {
      budget_setting: {
        property_type_id: apt.id, area_category: "mid",
        repair_cost: 500, acquisition_tax: 360,
        scrivener_fee: 80, moving_cost: 150, maintenance_fee: 50
      }
    }
    assert_response :success
    # The radio input carries the non-regulated ratio
    assert_select "input[type='radio'][name='budget_setting[loan_policy_id]'][data-loan-ratio='0.7']"
    assert_select "span.font-medium", text: "경락대출 (1금융)"
  end

  test "GET complete shows results" do
    get start_onboarding_url
    guest = User.find(session[:user_id])
    BudgetSetting.create!(
      user: guest, available_cash: 30000, loan_ratio: 0.7,
      max_bid_amount: 96200,
      completed_at: Time.current
    )
    get complete_onboarding_url
    assert_response :success
  end
end
