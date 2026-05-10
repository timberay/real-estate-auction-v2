require "test_helper"

# B21 / B-13: Onboarding validation errors render in Korean (attribute name +
# Korean message) and include an actionable hint explaining how to fix the
# input. Controller-level coverage avoids the JS layer; the system test
# covers a real browser submission for step1.
class OnboardingsValidationMessagesTest < ActionDispatch::IntegrationTest
  test "POST step1 with negative available_cash renders Korean error + hint" do
    get start_onboarding_url

    post step1_onboarding_url, params: { budget_setting: { available_cash: -100 } }
    assert_response :unprocessable_entity

    body = response.body
    # Attribute name (Korean) + Rails-default Korean message.
    assert_match(/쓸 수 있는 현금/, body)
    assert_match(/0보다 커야 합니다/, body)
    # Actionable hint: tells the user what to type.
    assert_match(/만원 단위/, body)
  end

  test "POST step3 with out-of-range loan_ratio renders Korean error + hint" do
    get start_onboarding_url
    # Walk to step3 with valid prior steps.
    post step1_onboarding_url, params: { budget_setting: { available_cash: 30000 } }
    apt = property_types(:apartment)
    post step2_onboarding_url, params: {
      budget_setting: {
        property_type_id: apt.id, area_category: "mid",
        repair_cost: 500, acquisition_tax: 360,
        scrivener_fee: 80, moving_cost: 150, maintenance_fee: 50
      }
    }

    policy = loan_policies(:auction_bank_apartment)
    post step3_onboarding_url, params: {
      budget_setting: { loan_policy_id: policy.id, loan_ratio: 1.5 }
    }
    assert_response :unprocessable_entity

    body = response.body
    assert_match(/대출 비율/, body)
    assert_match(/1 이하여야 합니다/, body)
    # Actionable hint: tells the user that loan_ratio is bound to the slider.
    assert_match(/슬라이더/, body)
  end

end
