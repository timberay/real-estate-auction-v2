require "test_helper"

class Auth::ProviderProfileTest < ActiveSupport::TestCase
  test "constructs with keyword args" do
    p = Auth::ProviderProfile.new(
      provider: "kakao", uid: "123", email: "a@b.com", email_verified: true,
      name: "홍길동", avatar_url: "http://x/y.jpg"
    )
    assert_equal "kakao", p.provider
    assert_equal "홍길동", p.name
    assert_equal true, p.email_verified
  end

  test "email may be nil (Kakao opt-out case)" do
    p = Auth::ProviderProfile.new(
      provider: "kakao", uid: "1", email: nil, email_verified: nil,
      name: "a", avatar_url: nil
    )
    assert_nil p.email
    assert_nil p.email_verified
  end
end
