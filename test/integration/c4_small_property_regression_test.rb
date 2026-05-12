require "test_helper"

# C-4 regression: before the bracket-iteration redesign, the onboarding flow
# computed acquisition_tax as `average_price × tax_rate` (e.g., 4.8억 × 1.1% =
# 528만원) regardless of the user's actual cash. For users with small cash
# budgets, that inflated tax pushed max_bid_amount below the floor for small
# auction properties — effectively blocking 1,000만원-class bids.
#
# This test locks in the fix: a user with 3,000만원 cash and 70% LTV completes
# onboarding successfully and ends up with a small auto-computed acquisition
# tax (~85만원) and a max_bid_amount that allows bidding on small properties.
class C4SmallPropertyRegressionTest < ActionDispatch::IntegrationTest
  test "small-cash user completes onboarding with small acquisition_tax" do
    get start_onboarding_url
    post step1_onboarding_url, params: { budget_setting: { available_cash: 3000, region: "경기도" } }

    apt = property_types(:apartment)
    post step2_onboarding_url, params: {
      budget_setting: {
        property_type_id: apt.id, area_category: "small",
        household_tier: "homeless", acquisition_tax_auto: "1",
        repair_cost: 400, scrivener_fee: 60, moving_cost: 100, maintenance_fee: 40
      }
    }

    policy = loan_policies(:auction_bank_apartment)
    post step3_onboarding_url, params: {
      budget_setting: { loan_policy_id: policy.id, loan_ratio: 0.7 }
    }
    assert_redirected_to complete_onboarding_url

    setting = User.find(session[:user_id]).budget_setting
    assert setting.completed?

    # Before C-4 fix: acquisition_tax would have been ~528 (static avg × rate),
    # crowding out max_bid below the small-property floor.
    # After fix: cash-derived bracket iteration lands in bracket 1 (1.1%).
    assert_operator setting.acquisition_tax, :<, 200,
                    "acquisition_tax should be small for a 3,000만원 cash scenario"
    assert_operator setting.max_bid_amount, :>=, 7_500,
                    "max_bid_amount should not be artificially depressed by inflated tax"
  end
end
