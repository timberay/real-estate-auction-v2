require "test_helper"

# B21 / B-14: server error page must read friendlier than just a flash + a
# 돌아가기 link. It now explains the transient nature of the error, offers
# a retry action, and points at a support contact.
class SharedErrorPageTest < ActionView::TestCase
  test "renders the flash message" do
    flash = ActionDispatch::Flash::FlashHash.new
    flash[:alert] = "외부 서비스에 연결할 수 없습니다."
    @virtual_path = "shared/error"

    rendered = render(template: "shared/error", layout: false, locals: { flash: flash })

    assert_match(/외부 서비스에 연결할 수 없습니다/, rendered)
  end

  test "renders friendlier transient-error guidance and retry button" do
    flash = ActionDispatch::Flash::FlashHash.new
    flash[:alert] = "오류"
    rendered = render(template: "shared/error", layout: false, locals: { flash: flash })

    # Friendlier copy explaining the situation + actionable retry CTA.
    assert_match(/일시적/, rendered)
    assert_match(/잠시 후|1분 뒤|다시 시도/, rendered)

    # A retry button (link). Goes to :back so users land where they started.
    assert_match(/다시 시도/, rendered)
  end

  test "renders a support contact line" do
    flash = ActionDispatch::Flash::FlashHash.new
    flash[:alert] = "오류"
    rendered = render(template: "shared/error", layout: false, locals: { flash: flash })

    # Support line directs users to email if the issue persists.
    assert_match(/문의/, rendered)
    assert_match(/@/, rendered, "support contact must include an email-like target")
  end

  test "support contact is not the placeholder address" do
    flash = ActionDispatch::Flash::FlashHash.new
    flash[:alert] = "오류"
    rendered = render(template: "shared/error", layout: false, locals: { flash: flash })

    refute_match(/@example\.com/, rendered,
      "support email must be a real ops address before launch (B21 follow-up)")
  end
end
