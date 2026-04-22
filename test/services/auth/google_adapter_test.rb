require "test_helper"

class Auth::GoogleAdapterTest < ActiveSupport::TestCase
  test "normalizes a standard google_oauth2 auth_hash" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "google_oauth2",
      "uid"      => "109876543210",
      "info"     => {
        "email" => "me@gmail.com",
        "name"  => "Jane Doe",
        "image" => "https://lh3.googleusercontent.com/a/x.jpg"
      },
      "extra"    => { "raw_info" => { "locale" => "ko" } }
    )
    profile = Auth::GoogleAdapter.new(auth_hash).to_profile
    assert_equal "google", profile.provider
    assert_equal "109876543210", profile.uid
    assert_equal "me@gmail.com", profile.email
    assert_equal "Jane Doe", profile.name
    assert_equal "https://lh3.googleusercontent.com/a/x.jpg", profile.avatar_url
  end

  test "maps info.email_verified true" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "google_oauth2", "uid" => "1",
      "info"  => { "email" => "x@y.com", "name" => "X", "image" => nil, "email_verified" => true },
      "extra" => { "raw_info" => {} }
    )
    profile = Auth::GoogleAdapter.new(auth_hash).to_profile
    assert_equal true, profile.email_verified
  end

  test "maps info.email_verified false" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "google_oauth2", "uid" => "2",
      "info"  => { "email" => "x@y.com", "name" => "X", "image" => nil, "email_verified" => false },
      "extra" => { "raw_info" => {} }
    )
    profile = Auth::GoogleAdapter.new(auth_hash).to_profile
    assert_equal false, profile.email_verified
  end

  test "maps missing email_verified as nil" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "google_oauth2", "uid" => "3",
      "info"  => { "email" => "x@y.com", "name" => "X", "image" => nil },
      "extra" => { "raw_info" => {} }
    )
    profile = Auth::GoogleAdapter.new(auth_hash).to_profile
    assert_nil profile.email_verified
  end
end
