require "test_helper"

class EvictionDeadlineJobTest < ActiveJob::TestCase
  setup do
    @user = users(:budget_user)
    @property = properties(:safe_apartment)
    @up = UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "no notification when payment_completed_on is nil" do
    @up.update!(payment_completed_on: nil)
    assert_no_difference "Notification.count" do
      EvictionDeadlineJob.perform_now
    end
  end

  test "creates D-30 notification when deadline is 30 days away" do
    travel_to Date.new(2026, 5, 14) do
      @up.update!(payment_completed_on: Date.new(2025, 12, 13))  # deadline 2026-06-13 (30 days away)
      assert_difference "Notification.count", 1 do
        EvictionDeadlineJob.perform_now
      end
      notif = Notification.last
      assert_equal "eviction_deadline_d30", notif.kind
      assert_match(/30일/, notif.title)
      assert_includes notif.action_url, @property.to_param
    end
  end

  test "creates D-7 notification when deadline is 7 days away" do
    travel_to Date.new(2026, 5, 14) do
      @up.update!(payment_completed_on: Date.new(2025, 11, 21))  # deadline 2026-05-21 (7 days)
      assert_difference "Notification.count", 1 do
        EvictionDeadlineJob.perform_now
      end
      assert_equal "eviction_deadline_d7", Notification.last.kind
    end
  end

  test "creates D-day notification when deadline is today" do
    travel_to Date.new(2026, 5, 14) do
      @up.update!(payment_completed_on: Date.new(2025, 11, 14))  # deadline 2026-05-14 (today)
      assert_difference "Notification.count", 1 do
        EvictionDeadlineJob.perform_now
      end
      assert_equal "eviction_deadline_d0", Notification.last.kind
    end
  end

  test "no notification at non-milestone days (e.g. D-15)" do
    travel_to Date.new(2026, 5, 14) do
      @up.update!(payment_completed_on: Date.new(2025, 11, 29))  # deadline 2026-05-29 (15 days)
      assert_no_difference "Notification.count" do
        EvictionDeadlineJob.perform_now
      end
    end
  end

  test "deduplicates within the same milestone — second run is a no-op" do
    travel_to Date.new(2026, 5, 14) do
      @up.update!(payment_completed_on: Date.new(2025, 12, 13))  # D-30
      EvictionDeadlineJob.perform_now
      assert_no_difference "Notification.count", "second run should not duplicate" do
        EvictionDeadlineJob.perform_now
      end
    end
  end

  test "still notifies a different user about a shared property" do
    travel_to Date.new(2026, 5, 14) do
      @up.update!(payment_completed_on: Date.new(2025, 12, 13))
      other_user = users(:guest)
      UserProperty.find_or_create_by!(user: other_user, property: @property).update!(payment_completed_on: Date.new(2025, 12, 13))

      assert_difference "Notification.count", 2 do
        EvictionDeadlineJob.perform_now
      end
    end
  end

  test "does not notify on past-deadline rows (no D-(-1) etc)" do
    travel_to Date.new(2026, 8, 14) do
      @up.update!(payment_completed_on: Date.new(2026, 1, 14))  # deadline 2026-07-14 (already past)
      assert_no_difference "Notification.count" do
        EvictionDeadlineJob.perform_now
      end
    end
  end
end
