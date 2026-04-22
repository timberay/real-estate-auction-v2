require "test_helper"

class SessionCreatorTest < ActiveSupport::TestCase
  setup do
    @guest = User.create!
    @existing = User.create!(guest: false, email: "me@example.com", name: "Me")
    @existing.identities.create!(provider: "kakao", uid: "100")
  end

  test "Case A: existing identity matches - logs into existing user and merges guest" do
    profile = Auth::ProviderProfile.new(
      provider: "kakao", uid: "100", email: "me@example.com",
      name: "Me", avatar_url: nil, raw_info: {}
    )
    result = SessionCreator.new(current_guest: @guest, profile: profile).call
    assert_equal @existing, result
    assert_raises(ActiveRecord::RecordNotFound) { @guest.reload }
  end

  test "Case B: email matches an existing account - attaches new identity and merges" do
    existing = User.create!(guest: false, email: "alice@example.com", name: "Alice")
    existing.identities.create!(provider: "kakao", uid: "kakao-1")

    profile = Auth::ProviderProfile.new(
      provider: "google", uid: "google-1", email: "alice@example.com",
      name: "Alice", avatar_url: nil, raw_info: {}
    )
    result = SessionCreator.new(current_guest: @guest, profile: profile).call

    assert_equal existing, result
    assert_equal 2, existing.reload.identities.count
    assert_includes existing.identities.pluck(:provider, :uid), [ "google", "google-1" ]
  end

  test "Case B: email nil does NOT match — falls to Case C" do
    User.create!(guest: false, email: nil, name: "AnonOne")
    profile = Auth::ProviderProfile.new(
      provider: "kakao", uid: "k-2", email: nil,
      name: "AnonTwo", avatar_url: nil, raw_info: {}
    )
    result = SessionCreator.new(current_guest: @guest, profile: profile).call
    refute_equal "AnonOne", result.name
    assert_equal @guest.id, result.id
    refute result.guest?
  end

  test "Case C: completely new user - promotes current guest in place preserving data" do
    prop = Property.create!(case_number: "2024-1111")
    @guest.user_properties.create!(property: prop)

    profile = Auth::ProviderProfile.new(
      provider: "google", uid: "new-1", email: "new@example.com",
      name: "New User", avatar_url: "http://x/y.jpg", raw_info: {}
    )
    result = SessionCreator.new(current_guest: @guest, profile: profile).call

    assert_equal @guest.id, result.id
    refute result.guest?
    assert_equal "new@example.com", result.email
    assert_equal "New User", result.name
    assert_equal "http://x/y.jpg", result.avatar_url
    assert_equal 1, result.user_properties.count
    assert_equal 1, result.identities.count
    assert_equal "google", result.identities.first.provider
  end
end
