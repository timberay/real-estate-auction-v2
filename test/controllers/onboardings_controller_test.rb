require "test_helper"

class OnboardingsControllerTest < ActionDispatch::IntegrationTest
  test "GET step1 renders the first step" do
    get start_onboarding_url
    assert_response :success
    assert_select "turbo-frame#onboarding_wizard"
  end

  test "GET step1 stacks the available cash input row vertically on mobile (C2)" do
    get start_onboarding_url
    assert_response :success

    # The cash input + "만원" + "다음" row must collapse to a column on narrow
    # screens so the controls don't squeeze.
    cash_input = css_select("input#available_cash_display").first
    assert cash_input, "expected available_cash_display input to be rendered"
    wrapper = cash_input.parent
    classes = wrapper["class"].to_s
    assert_includes classes, "flex-col",
      "expected cash input row wrapper to stack vertically on mobile"
    assert_includes classes, "sm:flex-row",
      "expected cash input row wrapper to switch to row at sm:"
  end

  test "GET step1 stacks the region select row vertically on mobile (C2)" do
    get start_onboarding_url
    assert_response :success

    region_select = css_select("select[name='budget_setting[region]']").first
    assert region_select, "expected region select to be rendered"
    wrapper = region_select.parent
    classes = wrapper["class"].to_s
    assert_includes classes, "flex-col",
      "expected region select row wrapper to stack vertically on mobile"
    assert_includes classes, "sm:flex-row",
      "expected region select row wrapper to switch to row at sm:"
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
    # C=30000, L=0.7, R(excl tax)=780; auto-mode iterates brackets and lands in bracket 3 (3.3%):
    # B = floor((30000-780)/(0.3+0.033)) = floor(29220/0.333) = 87747; T = round(0.033 × 87747) = 2896
    assert_equal 87_747, setting.max_bid_amount
    assert_equal 2_896, setting.acquisition_tax
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

  test "step2 renders all enabled property types as options in the 부동산 유형 select" do
    get start_onboarding_url
    post step1_onboarding_url, params: { budget_setting: { available_cash: 30000 } }
    assert_response :success

    enabled = PropertyType.enabled.ordered
    assert_operator enabled.count, :>, 0, "fixtures must provide at least one enabled property type"

    assert_select "select[name='budget_setting[property_type_id]']" do
      assert_select "option:not([value=''])", count: enabled.count
      enabled.each do |pt|
        assert_select "option[value='#{pt.id}']", text: pt.name
      end
    end
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
