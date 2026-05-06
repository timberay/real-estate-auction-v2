require "test_helper"

class GuestSessionTest < ActionDispatch::IntegrationTest
  test "first visit to a non-public action creates a new guest with its own user_id" do
    get start_onboarding_path
    assert User.exists?(session[:user_id])
    user = User.find(session[:user_id])
    assert user.guest?
  end

  test "two separate sessions get different guest user_ids" do
    session1 = open_session
    session1.get start_onboarding_path
    uid1 = session1.session[:user_id]

    session2 = open_session
    session2.get start_onboarding_path
    uid2 = session2.session[:user_id]

    refute_equal uid1, uid2, "two browsers must get distinct guest users"
  end

  test "GET request captures return_to_url in session" do
    get "/properties"
    assert_equal "/properties", session[:return_to_url]
  end

  test "HEAD request captures return_to_url in session" do
    head "/properties"
    assert_equal "/properties", session[:return_to_url]
  end

  test "POST request does NOT capture return_to_url" do
    get root_path
    before = session[:return_to_url]
    post "/properties", params: { case_number: "2024-test" }
    assert_equal before, session[:return_to_url], "POST must not overwrite return_to_url"
  end

  test "Auth::Error rescue_from redirects to login with flash" do
    ApplicationController.class_eval do
      alias_method :_orig_require_authenticated_user, :require_authenticated_user
      define_method(:require_authenticated_user) { raise Auth::ProviderError, "boom" }
    end

    get start_onboarding_path
    assert_redirected_to "/auth/login"
    assert_equal "로그인 중 문제가 발생했습니다. 다시 시도해주세요.", flash[:alert]
  ensure
    ApplicationController.class_eval do
      if private_method_defined?(:_orig_require_authenticated_user)
        alias_method :require_authenticated_user, :_orig_require_authenticated_user
        remove_method(:_orig_require_authenticated_user)
      end
    end
  end

  test "auth login route renders login page" do
    get "/auth/login"
    assert_response :success
  end

  test "header shows 로그인 link for guest" do
    get "/auth/login"  # a page that actually renders the layout (root redirects)
    assert_match(/로그인/, response.body)
    refute_match(/로그아웃/, response.body)
  end

  test "header shows user menu when logged in" do
    user = User.create!(guest: false, email: "m@n.com", name: "Menu User")
    post "/testing/sign_in", params: { user_id: user.id }
    get "/auth/login"
    assert_match "Menu User", response.body
    assert_match(/로그아웃/, response.body)
  end

  test "signed remember_token cookie restores session for returning account user" do
    user = User.create!(guest: false, email: "r@s.com", name: "Returnee")
    post "/testing/set_remember_cookie", params: { user_id: user.id }

    get "/auth/login"
    assert_match "Returnee", response.body
    assert_equal user.id, session[:user_id]
  end

  test "remember_token cookie is ignored for guest users" do
    guest = User.create!
    post "/testing/set_remember_cookie", params: { user_id: guest.id }

    get "/auth/login"
    refute_equal guest.id, session[:user_id], "should NOT reuse guest via remember cookie"
  end

  test "auth logout route accepts DELETE" do
    get root_path
    delete "/auth/logout"
    assert_redirected_to root_path
  end

  test "last_seen_at updates on request, throttled to once per minute" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    get start_onboarding_path
    user = User.find(session[:user_id])
    first = user.reload.last_seen_at
    assert_not_nil first

    travel 30.seconds do
      get start_onboarding_path
    end
    assert_equal first, user.reload.last_seen_at, "throttle must skip writes within 1 minute"

    travel 70.seconds do
      get start_onboarding_path
    end
    second = user.reload.last_seen_at
    assert second > first
  ensure
    Rails.cache = original_cache if original_cache
  end
end
