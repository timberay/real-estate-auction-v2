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

  test "DELETE destroy signs out and clears the session" do
    user = User.create!(guest: false, email: "x@y.com")
    post "/testing/sign_in", params: { user_id: user.id }

    delete "/auth/logout"
    assert_redirected_to root_path
    assert_nil session[:user_id], "session must be cleared on logout"
  end

  test "after logout, next non-public action creates a fresh guest" do
    user = User.create!(guest: false, email: "x@y.com")
    post "/testing/sign_in", params: { user_id: user.id }
    delete "/auth/logout"

    get start_onboarding_url
    refute_equal user.id, session[:user_id]
    assert User.find(session[:user_id]).guest?
  end

  # F-18: target="_blank" 외부/신탭 링크는 rel="noopener" 또는
  # rel="noopener noreferrer" 를 명시해 tabnabbing 을 방지해야 한다.
  test "login modal terms/privacy links use rel=noopener noreferrer" do
    get "/auth/login"
    assert_response :success

    [ "이용약관", "개인정보 처리방침" ].each do |label|
      assert_match(
        %r{<a[^>]*target="_blank"[^>]*rel="noopener noreferrer"[^>]*>#{Regexp.escape(label)}</a>}m,
        response.body,
        "login modal '#{label}' link must declare rel=noopener noreferrer when target=_blank"
      )
    end
  end
end
