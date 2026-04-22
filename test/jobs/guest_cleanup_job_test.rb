require "test_helper"

class GuestCleanupJobTest < ActiveJob::TestCase
  test "destroys guests last seen over 30 days ago" do
    old     = User.create!(last_seen_at: 31.days.ago)
    fresh   = User.create!(last_seen_at: 10.days.ago)
    account = User.create!(guest: false, email: "a@b.com", last_seen_at: 60.days.ago)

    GuestCleanupJob.perform_now

    assert_raises(ActiveRecord::RecordNotFound) { old.reload }
    assert fresh.reload.persisted?
    assert account.reload.persisted?
  end

  test "cascades dependent associations on destroy" do
    guest = User.create!(last_seen_at: 31.days.ago)
    prop  = Property.create!(case_number: "CASE-CLEAN")
    guest.user_properties.create!(property: prop)

    GuestCleanupJob.perform_now

    assert_equal 0, UserProperty.where(user_id: guest.id).count
  end
end
