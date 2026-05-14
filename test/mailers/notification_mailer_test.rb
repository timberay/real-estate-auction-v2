require "test_helper"

class NotificationMailerTest < ActionMailer::TestCase
  test "notify renders subject from title and body, includes action_url when present" do
    user = users(:budget_user)
    notif = user.notifications.create!(
      kind: "eviction_deadline",
      title: "인도명령 신청 기한 30일 전",
      body: "사건 2026타경1234 — 6개월 내 명도소송이 권장됩니다.",
      action_url: "https://example.test/properties/1"
    )

    mail = NotificationMailer.notify(notif)
    assert_equal "인도명령 신청 기한 30일 전", mail.subject
    assert_equal [ user.email ], mail.to
    text = mail.text_part.body.to_s
    assert_includes text, "사건 2026타경1234"
    assert_includes text, "https://example.test/properties/1"
  end

  test "notify omits action_url section when nil" do
    user = users(:budget_user)
    notif = user.notifications.create!(kind: "x", title: "title only", body: "plain body")

    mail = NotificationMailer.notify(notif)
    assert_equal "title only", mail.subject
    refute_includes mail.text_part.body.to_s, "확인하기"
  end
end
