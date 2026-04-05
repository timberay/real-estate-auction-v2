require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "redirects to onboarding when no budget settings" do
    get root_url
    assert_redirected_to start_onboarding_url
  end

  test "shows home page when budget settings completed" do
    user = User.create!(email: "home@test.com", password: "password")
    BudgetSetting.create!(
      user: user,
      available_cash: 30000,
      loan_ratio: 0.7,
      area_unit: "pyeong",
      failed_auction_rounds: 0,
      completed_at: Time.current
    )

    # Simulate guest session pointing to this user
    get root_url
    # First visit creates guest session, which has no budget settings -> redirect
    assert_redirected_to start_onboarding_url
  end

  test "auto-creates guest session on first visit" do
    User.where(email: "guest@auction.local").delete_all
    assert_difference "User.count", 1 do
      get root_url
    end
  end

  test "does not create duplicate guest user on second visit" do
    get root_url
    assert_no_difference "User.count" do
      get root_url
    end
  end
end
