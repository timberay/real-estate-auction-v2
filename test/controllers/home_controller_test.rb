require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows landing to unauthenticated visitor" do
    get root_url
    assert_response :success
    assert_select "h1", text: "법원 경매 권리분석 도구"
  end

  test "redirects to properties when budget settings completed" do
    # Bootstrap a guest via a non-public action that runs require_authenticated_user.
    get start_onboarding_url
    user = User.find(session[:user_id])
    BudgetSetting.create!(
      user: user,
      available_cash: 30000,
      loan_ratio: 0.7,
      completed_at: Time.current
    )

    get root_url
    assert_redirected_to properties_path
  end

  test "does NOT auto-create a user on landing visit (lazy guest creation)" do
    assert_no_difference "User.count" do
      get root_url
    end
  end

  test "repeat anonymous visits never create users" do
    assert_no_difference "User.count" do
      3.times { get root_url }
    end
  end
end
