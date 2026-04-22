require "test_helper"

class ConcurrentLoginTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  teardown do
    Identity.where(provider: "kakao", uid: "race-1").delete_all
    User.where(email: "race@example.com").delete_all
    User.where(guest: true, email: nil).delete_all
  end

  test "two simultaneous Case C callbacks for the same guest produce exactly one user" do
    guest = User.create!
    profile = Auth::ProviderProfile.new(
      provider: "kakao", uid: "race-1", email: "race@example.com",
      name: "R", avatar_url: nil, raw_info: {}
    )

    errors = []
    threads = 2.times.map do
      Thread.new do
        begin
          SessionCreator.new(current_guest: guest, profile: profile).call
        rescue => e
          errors << e
        end
      end
    end
    threads.each(&:join)

    assert_equal 1, Identity.where(provider: "kakao", uid: "race-1").count
    assert_equal 1, User.where(email: "race@example.com", guest: false).count
  end
end
