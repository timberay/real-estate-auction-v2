require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
  end

  test "valid with required attributes" do
    notif = Notification.new(user: @user, kind: "eviction_deadline", title: "D-30", body: "인도명령 신청 기한이 30일 남았습니다.")
    assert notif.valid?
  end

  test "invalid without user" do
    notif = Notification.new(kind: "x", title: "y")
    assert_not notif.valid?
    assert notif.errors[:user].any?
  end

  test "invalid without kind" do
    notif = Notification.new(user: @user, title: "y")
    assert_not notif.valid?
    assert notif.errors[:kind].any?
  end

  test "invalid without title" do
    notif = Notification.new(user: @user, kind: "x")
    assert_not notif.valid?
    assert notif.errors[:title].any?
  end

  test "read? returns false when read_at is nil" do
    notif = Notification.new(user: @user, kind: "x", title: "y")
    assert_not notif.read?
  end

  test "read? returns true when read_at is set" do
    notif = Notification.new(user: @user, kind: "x", title: "y", read_at: Time.current)
    assert notif.read?
  end

  test "mark_read! sets read_at and persists" do
    notif = Notification.create!(user: @user, kind: "x", title: "y")
    travel_to Time.current do
      notif.mark_read!
      assert_in_delta Time.current.to_f, notif.reload.read_at.to_f, 1
    end
  end

  test "mark_read! is idempotent (does not overwrite existing read_at)" do
    earlier = 1.hour.ago
    notif = Notification.create!(user: @user, kind: "x", title: "y", read_at: earlier)
    notif.mark_read!
    assert_in_delta earlier.to_f, notif.reload.read_at.to_f, 1
  end

  test ".unread scope filters out read notifications" do
    Notification.create!(user: @user, kind: "x", title: "unread")
    Notification.create!(user: @user, kind: "x", title: "already-read", read_at: Time.current)
    assert_equal [ "unread" ], @user.notifications.unread.pluck(:title)
  end

  test "ordered_recent returns most recent first" do
    old = Notification.create!(user: @user, kind: "x", title: "old", created_at: 2.days.ago)
    new_ = Notification.create!(user: @user, kind: "x", title: "new", created_at: 1.minute.ago)
    assert_equal [ new_.id, old.id ], @user.notifications.ordered_recent.pluck(:id)
  end
end
