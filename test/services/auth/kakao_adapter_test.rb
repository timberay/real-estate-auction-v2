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

  test "maps kakao_account.is_email_verified true" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "kakao", "uid" => "1",
      "info"  => { "email" => "a@b.com", "name" => "X", "image" => nil },
      "extra" => { "raw_info" => { "kakao_account" => { "is_email_verified" => true } } }
    )
    assert_equal true, Auth::KakaoAdapter.new(auth_hash).to_profile.email_verified
  end

  test "maps kakao_account.is_email_verified false" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "kakao", "uid" => "2",
      "info"  => { "email" => "a@b.com", "name" => "X", "image" => nil },
      "extra" => { "raw_info" => { "kakao_account" => { "is_email_verified" => false } } }
    )
    assert_equal false, Auth::KakaoAdapter.new(auth_hash).to_profile.email_verified
  end

  test "kakao_account missing → email_verified is nil" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "kakao", "uid" => "3",
      "info"  => { "email" => nil, "name" => "익명", "image" => nil },
      "extra" => { "raw_info" => {} }
    )
    assert_nil Auth::KakaoAdapter.new(auth_hash).to_profile.email_verified
  end
end
