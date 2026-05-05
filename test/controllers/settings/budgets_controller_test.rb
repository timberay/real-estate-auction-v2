require "test_helper"

class Settings::BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_url  # create guest session
    @user = User.find(session[:user_id])
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
      completed_at: Time.current
    )
  end

  test "GET show renders budget settings" do
    get settings_budget_url
    assert_response :success
  end

  test "GET show renders auto-calc checkbox checked by default" do
    get settings_budget_url
    assert_select "input[data-reserve-fund-target='autoCalc'][checked]"
  end

  test "GET show submit button renders visible save label" do
    get settings_budget_url
    assert_select "button[type='submit']", text: /저장/
  end

  test "PATCH update_region saves region and returns ok" do
    patch update_region_settings_budget_url, params: {
      budget_setting: { region: "서울특별시" }
    }
    assert_response :ok
    assert_equal "서울특별시", @setting.reload.region
  end

  test "PATCH update_region rejects invalid region" do
    patch update_region_settings_budget_url, params: {
      budget_setting: { region: "존재하지않는지역" }
    }
    assert_response :unprocessable_entity
    assert_equal BudgetSetting::DEFAULT_REGION, @setting.reload.region
  end

  test "GET show checks the radio for an equivalent policy when loan_policy_id is stale across property types" do
    @setting.update!(
      property_type: property_types(:officetel),
      loan_policy: loan_policies(:auction_capital_apartment) # stale: belongs to apartment, not officetel
    )

    get settings_budget_url
    assert_response :success

    expected_policy = loan_policies(:auction_capital_officetel)
    assert_select "input[type='radio'][name='budget_setting[loan_policy_id]'][value=?][checked='checked']",
                  expected_policy.id.to_s
  end

  test "GET show does not persist the remap to the database" do
    @setting.update!(
      property_type: property_types(:officetel),
      loan_policy: loan_policies(:auction_capital_apartment)
    )
    stale_id = loan_policies(:auction_capital_apartment).id

    get settings_budget_url
    assert_response :success

    assert_equal stale_id, @setting.reload.loan_policy_id
  end

  test "PATCH update saves new settings and creates snapshot" do
    patch settings_budget_url, params: {
      budget_setting: {
        available_cash: 40000,
        property_type_id: property_types(:apartment).id,
        area_category: "mid",
        repair_cost: 500,
        acquisition_tax: 360,
        scrivener_fee: 80,
        moving_cost: 150,
        maintenance_fee: 50,
        loan_policy_id: loan_policies(:auction_bank_apartment).id,
        loan_ratio: 0.7
      }
    }

    assert_redirected_to settings_budget_url
    @setting.reload
    assert_equal 40000, @setting.available_cash
  end
end
