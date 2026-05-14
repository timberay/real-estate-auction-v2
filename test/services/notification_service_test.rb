require "test_helper"

class NotificationServiceTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  include ActionMailer::TestHelper

  setup do
    @user = users(:budget_user)    # has email
    @guest = users(:guest_two)     # no email
  end

  test "create_for persists a notification" do
    assert_difference "Notification.count", 1 do
      NotificationService.create_for(
        user: @user, kind: "test", title: "hello", body: "world", action_url: "/x"
      )
    end
    notif = Notification.last
    assert_equal "test", notif.kind
    assert_equal "hello", notif.title
    assert_equal "world", notif.body
    assert_equal "/x", notif.action_url
    assert_nil notif.read_at
  end

  test "create_for enqueues NotificationMailer when user has email" do
    assert_enqueued_emails 1 do
      NotificationService.create_for(user: @user, kind: "test", title: "hello")
    end
  end

  test "create_for skips email when user has no email address" do
    assert_no_enqueued_emails do
      NotificationService.create_for(user: @guest, kind: "test", title: "hello")
    end
  end

  test "create_for skips email when email: false is passed" do
    assert_no_enqueued_emails do
      NotificationService.create_for(user: @user, kind: "test", title: "hello", email: false)
    end
  end

  test "create_for broadcasts notification badge update to user channel" do
    channel = "user_#{@user.id}_notifications"
    messages = capture_broadcasts(channel) do
      NotificationService.create_for(user: @user, kind: "test", title: "hello")
    end
    payload = messages.map(&:to_s).join
    assert_includes payload, "notification_badge",
      "expected badge target in broadcast payload"
  end

  test "create_for returns the persisted notification" do
    notif = NotificationService.create_for(user: @user, kind: "test", title: "hello")
    assert_kind_of Notification, notif
    assert notif.persisted?
  end
end
