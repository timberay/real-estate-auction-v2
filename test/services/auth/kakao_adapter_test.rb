require "test_helper"

class Auth::KakaoAdapterTest < ActiveSupport::TestCase
  test "normalizes a kakao auth_hash with email" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "kakao",
      "uid"      => "1234567890",
      "info"     => { "email" => "user@kakao.test", "name" => "홍길동", "image" => "https://k.kakaocdn.net/p.jpg" },
      "extra"    => { "raw_info" => { "kakao_account" => { "email" => "user@kakao.test" } } }
    )
    profile = Auth::KakaoAdapter.new(auth_hash).to_profile
    assert_equal "kakao", profile.provider
    assert_equal "user@kakao.test", profile.email
    assert_equal "홍길동", profile.name
  end

  test "email is nil when Kakao user opted out of email consent" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "kakao",
      "uid"      => "9999",
      "info"     => { "email" => nil, "name" => "익명", "image" => nil },
      "extra"    => { "raw_info" => { "kakao_account" => { "has_email" => false } } }
    )
    profile = Auth::KakaoAdapter.new(auth_hash).to_profile
    assert_nil profile.email
    assert_equal "익명", profile.name
  end
end
