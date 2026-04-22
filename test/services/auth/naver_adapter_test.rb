require "test_helper"

class Auth::NaverAdapterTest < ActiveSupport::TestCase
  test "normalizes a naver auth_hash" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "naver",
      "uid"      => "naver-user-001",
      "info"     => { "email" => "u@naver.com", "name" => "네이버유저", "image" => "https://ssl.pstatic.net/x.jpg" },
      "extra"    => { "raw_info" => { "response" => { "profile_image" => "https://ssl.pstatic.net/x.jpg" } } }
    )
    profile = Auth::NaverAdapter.new(auth_hash).to_profile
    assert_equal "naver", profile.provider
    assert_equal "naver-user-001", profile.uid
    assert_equal "네이버유저", profile.name
  end

  test "falls back to raw_info.response.profile_image when info.image is missing" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "naver",
      "uid"      => "xyz",
      "info"     => { "email" => "a@b.com", "name" => "X", "image" => nil },
      "extra"    => { "raw_info" => { "response" => { "profile_image" => "https://fallback/x.jpg" } } }
    )
    profile = Auth::NaverAdapter.new(auth_hash).to_profile
    assert_equal "https://fallback/x.jpg", profile.avatar_url
  end

  test "maps response.email_verified true" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "naver", "uid" => "1",
      "info"  => { "email" => "a@b.com", "name" => "X", "image" => nil },
      "extra" => { "raw_info" => { "response" => { "email_verified" => true } } }
    )
    assert_equal true, Auth::NaverAdapter.new(auth_hash).to_profile.email_verified
  end

  test "response.email_verified absent → nil" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "naver", "uid" => "2",
      "info"  => { "email" => "a@b.com", "name" => "X", "image" => nil },
      "extra" => { "raw_info" => { "response" => {} } }
    )
    assert_nil Auth::NaverAdapter.new(auth_hash).to_profile.email_verified
  end

  test "raw_info absent → nil (no exception)" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "naver", "uid" => "3",
      "info"  => { "email" => "a@b.com", "name" => "X", "image" => nil },
      "extra" => {}
    )
    assert_nil Auth::NaverAdapter.new(auth_hash).to_profile.email_verified
  end
end
