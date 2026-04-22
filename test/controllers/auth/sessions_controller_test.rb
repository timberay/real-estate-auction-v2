require "test_helper"

class Auth::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET new renders login modal" do
    get "/auth/login"
    assert_response :success
    assert_match "카카오로 계속하기", response.body
    assert_match "네이버로 계속하기", response.body
    assert_match "Google로 계속하기", response.body
  end

  test "last_provider cookie floats matching button to top" do
    cookies[:last_provider] = "google"
    get "/auth/login"
    kakao_pos  = response.body.index("카카오로 계속하기")
    google_pos = response.body.index("Google로 계속하기")
    assert google_pos < kakao_pos, "Google button should appear before Kakao when last_provider=google"
  end

  test "DELETE destroy signs out and resets to new guest" do
    user = User.create!(guest: false, email: "x@y.com")
    post "/testing/sign_in", params: { user_id: user.id }

    delete "/auth/logout"
    assert_redirected_to root_path

    get root_path
    refute_equal user.id, session[:user_id]
    assert User.find(session[:user_id]).guest?
  end
end
