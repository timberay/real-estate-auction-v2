require "test_helper"

class Auth::ProviderProfileTest < ActiveSupport::TestCase
  test "constructs with keyword args" do
    p = Auth::ProviderProfile.new(
      provider: "kakao", uid: "123", email: "a@b.com",
      name: "홍길동", avatar_url: "http://x/y.jpg", raw_info: {}
    )
    assert_equal "kakao", p.provider
    assert_equal "홍길동", p.name
  end

  test "email may be nil (Kakao opt-out case)" do
    p = Auth::ProviderProfile.new(
      provider: "kakao", uid: "1", email: nil,
      name: "a", avatar_url: nil, raw_info: {}
    )
    assert_nil p.email
  end
end
