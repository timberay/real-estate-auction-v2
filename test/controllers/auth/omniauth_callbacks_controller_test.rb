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

    mock_omniauth(:google_oauth2, uid: "google-1", email: "alice@example.com", name: "Alice")
    get "/auth/google_oauth2/callback"

    assert_redirected_to root_path
    assert_equal existing.id, session[:user_id]
    assert_equal 2, existing.reload.identities.count
  end

  test "Case C: completely new user - promotes current guest in place" do
    get root_path
    guest_id = session[:user_id]

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

    get root_path
    guest_id = session[:user_id]

    mock_omniauth(:kakao, uid: "no-email", email: nil, name: "NewAnon")
    get "/auth/kakao/callback"

    assert_redirected_to root_path
    promoted = User.find(session[:user_id])
    assert_equal guest_id, promoted.id, "should promote the CURRENT guest, not link to OldAnon"
    refute_equal "OldAnon", promoted.name
  end
end
