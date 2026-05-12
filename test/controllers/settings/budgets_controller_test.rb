require "test_helper"

class Settings::BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url  # create guest session via non-public action
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

  test "PATCH update_region builds a budget_setting when the user has none yet" do
    # Onboarding step1 fires region-select ajax before the form has been submitted,
    # so current_user.budget_setting can be nil. The endpoint must not 500.
    @setting.destroy!
    @user.reload

    patch update_region_settings_budget_url, params: {
      budget_setting: { region: "서울특별시" }
    }

    assert_response :ok
    assert_equal "서울특별시", @user.reload.budget_setting&.region
  end

  test "GET show exposes loan policies for every enabled property type as JSON for client-side switching" do
    get settings_budget_url
    assert_response :success

    payload_attr = css_select("[data-budget-calculator-loan-policies-by-type-value]").first
    assert payload_attr, "expected the form to expose loan policies grouped by property type"

    payload = JSON.parse(payload_attr["data-budget-calculator-loan-policies-by-type-value"])

    PropertyType.enabled.ordered.each do |pt|
      policies = payload[pt.id.to_s]
      assert policies.present?, "expected payload to include policies for property type #{pt.code}"
      policies.each do |p|
        assert_kind_of Numeric, p["loan_ratio"]
        assert_kind_of Numeric, p["regulated_loan_ratio"]
      end
    end
  end

  test "GET show exposes the regulated regions list for client-side switching" do
    get settings_budget_url
    assert_response :success

    form = css_select("[data-budget-calculator-regulated-regions-value]").first
    assert form, "expected form to expose regulated regions"
    regions = JSON.parse(form["data-budget-calculator-regulated-regions-value"])
    assert_includes regions, "서울특별시"
  end

  test "GET show wires the region select to the budget-calculator stimulus action" do
    get settings_budget_url
    assert_response :success

    select = css_select("select[name='budget_setting[region]']").first
    assert select, "expected region select to be rendered"
    assert_includes select["data-action"].to_s, "change->budget-calculator#regionChanged"
  end

  test "GET show renders LTV using regulated rate when region is Seoul" do
    @setting.update!(
      region: "서울특별시",
      property_type: property_types(:apartment),
      loan_policy: loan_policies(:auction_bank_apartment),
      loan_ratio: 0.4
    )

    get settings_budget_url
    assert_response :success

    # Apartment 1금융 비규제 70% / 규제 40% — Seoul should display 40%
    assert_select "[data-budget-calculator-target='loanRatioDisplay']", text: "40%"
    assert_select "input[type='range'][data-budget-calculator-target='loanRatioSlider'][value='40']"
    # The radio label should reflect the regulated LTV
    assert_select "[data-budget-calculator-target='loanPolicyList']" do
      assert_select "label", text: /경락대출 \(1금융\).*LTV 40%/m
    end
  end

  test "GET show renders LTV using non-regulated rate when region is not Seoul" do
    @setting.update!(
      region: "경기도",
      property_type: property_types(:apartment),
      loan_policy: loan_policies(:auction_bank_apartment),
      loan_ratio: 0.7
    )

    get settings_budget_url
    assert_response :success

    assert_select "[data-budget-calculator-target='loanRatioDisplay']", text: "70%"
    assert_select "[data-budget-calculator-target='loanPolicyList']" do
      assert_select "label", text: /경락대출 \(1금융\).*LTV 70%/m
    end
  end

  test "GET show wires the property type select to the budget-calculator stimulus action" do
    get settings_budget_url
    assert_response :success

    select = css_select("select[name='budget_setting[property_type_id]']").first
    assert select, "expected property type select to be rendered"
    assert_includes select["data-action"].to_s, "change->budget-calculator#propertyTypeChanged"
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

  test "GET show remaps loan_ratio along with loan_policy_id when stale" do
    @setting.update!(
      property_type: property_types(:officetel),
      loan_policy: loan_policies(:auction_capital_apartment), # apartment 2금융 (0.9)
      loan_ratio: 0.9
    )

    get settings_budget_url
    assert_response :success

    # officetel 2금융 = 0.8, slider should reflect 80%
    assert_select "input[type='range'][data-budget-calculator-target='loanRatioSlider'][value='80']"
    assert_select "[data-budget-calculator-target='loanRatioDisplay']", text: "80%"
  end

  test "GET show renders the LTV slider with min=30, max=100 (covers regulated 40% floor)" do
    get settings_budget_url
    assert_response :success
    assert_select "input[type='range'][min='30'][max='100'][data-budget-calculator-target='loanRatioSlider']"
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

  test "GET show redirects to onboarding without raising when budget_setting is missing" do
    @setting.destroy!

    assert_nothing_raised do
      get settings_budget_url
    end
    assert_redirected_to start_onboarding_url
  end

  test "GET show redirects to onboarding without raising when budget_setting is incomplete" do
    @setting.update!(completed_at: nil)

    assert_nothing_raised do
      get settings_budget_url
    end
    assert_redirected_to start_onboarding_url
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

  test "PATCH update persists acquisition_tax_precise_mode opt-in" do
    assert_equal false, @setting.acquisition_tax_precise_mode

    patch settings_budget_url, params: {
      budget_setting: {
        available_cash: @setting.available_cash,
        property_type_id: @setting.property_type_id,
        area_category: "mid",
        loan_policy_id: @setting.loan_policy_id,
        loan_ratio: @setting.loan_ratio,
        acquisition_tax_precise_mode: "1"
      }
    }

    assert_redirected_to settings_budget_url
    assert_equal true, @setting.reload.acquisition_tax_precise_mode
  end
end
