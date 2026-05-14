require "test_helper"

class Auth::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  test "Case A: existing identity logs user in and redirects to return_to_url" do
    user = User.create!(guest: false, email: "a@b.com", name: "A")
    user.identities.create!(provider: "kakao", uid: "k-1")

    get "/properties"
    mock_omniauth(:kakao, uid: "k-1", email: "a@b.com", name: "A")

    get "/auth/kakao/callback"
    assert_redirected_to "/properties"
    assert_equal user.id, session[:user_id]
  end

  test "Case B: email matches existing account - attaches new identity and logs in" do
    existing = User.create!(guest: false, email: "alice@example.com", name: "Alice")
    existing.identities.create!(provider: "kakao", uid: "kakao-1")

    mock_omniauth(:google_oauth2, uid: "google-1", email: "alice@example.com",
                  name: "Alice", email_verified: true)
    get "/auth/google_oauth2/callback"

    assert_redirected_to root_path
    assert_equal existing.id, session[:user_id]
    assert_equal 2, existing.reload.identities.count
  end

  test "Case C: completely new user - promotes current guest in place" do
    guest = User.create!
    post "/testing/sign_in", params: { user_id: guest.id }
    guest_id = guest.id

    mock_omniauth(:google_oauth2, uid: "g-new", email: "new@example.com", name: "New")
    get "/auth/google_oauth2/callback"

    assert_redirected_to root_path
    promoted = User.find(session[:user_id])
    assert_equal guest_id, promoted.id
    refute promoted.guest?
    assert_equal "new@example.com", promoted.email
  end

  test "Case C nil-email: Kakao user without email still promotes guest (no spurious Case B match)" do
    User.create!(guest: false, email: nil, name: "OldAnon")

    guest = User.create!
    post "/testing/sign_in", params: { user_id: guest.id }
    guest_id = guest.id

    mock_omniauth(:kakao, uid: "no-email", email: nil, name: "NewAnon")
    get "/auth/kakao/callback"

    assert_redirected_to root_path
    promoted = User.find(session[:user_id])
    assert_equal guest_id, promoted.id, "should promote the CURRENT guest, not link to OldAnon"
    refute_equal "OldAnon", promoted.name
  end

  test "failure with access_denied shows cancel message" do
    get "/auth/failure?message=access_denied"
    assert_redirected_to "/auth/login"
    assert_equal "로그인이 취소되었습니다.", flash[:alert]
  end

  test "failure with csrf_detected shows security message" do
    get "/auth/failure?message=csrf_detected"
    assert_redirected_to "/auth/login"
    assert_match(/보안 검증/, flash[:alert])
  end

  test "failure with unknown code shows generic message" do
    get "/auth/failure?message=something_weird"
    assert_redirected_to "/auth/login"
    assert_match(/문제가 발생/, flash[:alert])
  end

  test "successful callback rotates session id (fixation defense)" do
    get root_path
    old_session_data = session.to_hash.dup

    mock_omniauth(:google_oauth2, uid: "g-x", email: "x@y.com", name: "X")
    get "/auth/google_oauth2/callback"

    assert session[:user_id].present?
    refute_equal old_session_data["return_to_url"], session[:return_to_url]
  end

  test "GET /auth/google_oauth2 request phase is rejected (POST only)" do
    get "/auth/google_oauth2"
    assert_response :not_found
  end

  test "post-origin trigger surfaces 'try again' toast after login" do
    get root_path
    post "/testing/set_session", params: { pending_post_action: "PDF 내보내기" }

    mock_omniauth(:kakao, uid: "x", email: "x@y.com", name: "X")
    get "/auth/kakao/callback"

    assert_match "PDF 내보내기를 다시 눌러주세요", flash[:notice]
  end

  # W0-4 regression: the controller does ADAPTERS[…["provider"].to_s], so a
  # Symbol provider value (which OmniAuth strategies can produce) must still
  # route correctly. Guard against accidental removal of the `.to_s` defense.
  test "Symbol provider in omniauth.auth still routes to the correct adapter" do
    mock_omniauth(:kakao, uid: "sym-1", email: "sym@example.com", name: "Sym")
    # Replace the provider key with a Symbol — this is the exact regression we
    # want to guard against.
    OmniAuth.config.mock_auth[:kakao]["provider"] = :kakao

    assert_difference -> { User.where.not(guest: true).count }, 1 do
      get "/auth/kakao/callback"
    end

    assert_redirected_to root_path
    user = User.find(session[:user_id])
    assert_equal "sym@example.com", user.email
    assert_equal "kakao", user.identities.first.provider
  end

  test "Symbol provider for google_oauth2 still resolves the adapter" do
    mock_omniauth(:google_oauth2, uid: "sym-g", email: "g@example.com", name: "G")
    OmniAuth.config.mock_auth[:google_oauth2]["provider"] = :google_oauth2

    get "/auth/google_oauth2/callback"

    assert_redirected_to root_path
    user = User.find(session[:user_id])
    # GoogleAdapter normalizes the persisted provider to "google" (PROVIDER constant).
    assert_equal "google", user.identities.first.provider
  end
end
