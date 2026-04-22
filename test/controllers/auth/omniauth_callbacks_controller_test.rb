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
end
