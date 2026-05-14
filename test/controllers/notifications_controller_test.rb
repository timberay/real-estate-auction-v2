require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership
    @notif1 = @user.notifications.create!(kind: "x", title: "first", body: "body1", action_url: "/properties/1")
    @notif2 = @user.notifications.create!(kind: "x", title: "second", body: "body2", read_at: Time.current)
  end

  test "GET /notifications requires auth" do
    delete auth_logout_url
    get notifications_url
    assert_redirected_to auth_login_url
  end

  test "GET /notifications renders the user's notifications" do
    get notifications_url
    assert_response :success
    assert_select "h1", text: /알림/
    assert_select "li", count: 2
    assert_includes response.body, "first"
    assert_includes response.body, "second"
  end

  test "GET /notifications shows unread + read with visual distinction" do
    get notifications_url
    assert_response :success
    assert_select "li[data-read='false']", count: 1
    assert_select "li[data-read='true']", count: 1
  end

  test "POST /notifications/:id/mark_read marks the notification as read" do
    assert_nil @notif1.read_at
    post mark_read_notification_url(@notif1)
    assert_redirected_to notifications_url
    assert_not_nil @notif1.reload.read_at
  end

  test "POST /notifications/:id/mark_read on already-read notification is idempotent" do
    original = @notif2.read_at
    travel 1.minute do
      post mark_read_notification_url(@notif2)
      assert_redirected_to notifications_url
    end
    assert_in_delta original.to_f, @notif2.reload.read_at.to_f, 1
  end

  test "POST /notifications/:id/mark_read refuses notifications belonging to another user" do
    other = users(:budget_user).notifications.create!(kind: "x", title: "other")
    post mark_read_notification_url(other)
    assert_response :not_found
    assert_nil other.reload.read_at
  end
end
