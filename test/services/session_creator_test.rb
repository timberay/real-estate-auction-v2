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
end
