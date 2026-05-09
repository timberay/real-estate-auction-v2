require "test_helper"

# Behavior introduced in PR-1 (pre-launch hardening):
# Anonymous GETs to public pages MUST NOT create a User row.
# Protected pages MUST redirect to login when no current_user exists.
# Onboarding entry MUST lazily create a guest on first visit.
class LazyGuestCreationTest < ActionDispatch::IntegrationTest
  test "anonymous GET / does not create a User" do
    assert_no_difference "User.count" do
      get root_url
    end
    assert_response :success
  end

  test "anonymous repeated GETs to public pages do not accumulate User rows" do
    assert_no_difference "User.count" do
      10.times { get root_url }
      5.times  { get terms_url }
      5.times  { get privacy_url }
    end
  end

  test "anonymous GET /properties redirects to login without creating a User" do
    assert_no_difference "User.count" do
      get properties_url
    end
    assert_redirected_to auth_login_path
  end

  test "anonymous GET /search redirects to login without creating a User" do
    assert_no_difference "User.count" do
      get search_url
    end
    assert_redirected_to auth_login_path
  end

  test "anonymous POST /search_results redirects to login without creating a User" do
    assert_no_difference "User.count" do
      post search_results_url, as: :turbo_stream
    end
    assert_redirected_to auth_login_path
  end

  test "GET /onboarding/start lazily creates a guest user on first visit" do
    assert_difference "User.count", 1 do
      get start_onboarding_url
    end
    assert_response :success
    user = User.find(session[:user_id])
    assert user.guest?, "newly created user via onboarding entry must be a guest"
  end

  test "second GET /onboarding/start in same session reuses the guest" do
    get start_onboarding_url
    first_user_id = session[:user_id]

    assert_no_difference "User.count" do
      get start_onboarding_url
    end
    assert_equal first_user_id, session[:user_id]
  end

  test "GET /auth/login does not create a User" do
    assert_no_difference "User.count" do
      get auth_login_url
    end
    assert_response :success
  end
end
