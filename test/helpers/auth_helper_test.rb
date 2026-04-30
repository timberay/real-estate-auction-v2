require "test_helper"

class AuthHelperTest < ActionView::TestCase
  include AuthHelper

  test "#provider_path returns /auth/<provider> when no sub-path" do
    @request = ActionDispatch::TestRequest.create
    @request.script_name = ""
    define_singleton_method(:request) { @request }
    assert_equal "/auth/kakao", provider_path("kakao")
  end

  test "#provider_path returns /<prefix>/auth/<provider> under sub-path" do
    @request = ActionDispatch::TestRequest.create
    @request.script_name = "/real-estate-auction"
    define_singleton_method(:request) { @request }
    assert_equal "/real-estate-auction/auth/google_oauth2", provider_path("google_oauth2")
  end
end
