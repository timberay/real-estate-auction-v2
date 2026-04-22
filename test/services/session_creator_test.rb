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
end
