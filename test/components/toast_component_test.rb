# frozen_string_literal: true

require "test_helper"

class ToastComponentTest < ViewComponent::TestCase
  # --- Basic rendering ---

  test "renders info toast by default" do
    render_inline(ToastComponent.new(message: "알림 메시지"))

    assert_text "알림 메시지"
    assert_selector "div[class*='flex']"
    assert_selector "div[class*='items-start']"
    assert_selector "div[class*='gap-3']"
    assert_selector "div[class*='rounded-lg']"
    assert_selector "div[class*='shadow-lg']"
    assert_selector "div[class*='min-w-80']"
    assert_selector "div[class*='max-w-md']"
    assert_selector "div[class*='pointer-events-auto']"
  end

  # --- Stimulus controller ---

  test "includes toast stimulus controller" do
    render_inline(ToastComponent.new(message: "메시지"))

    assert_selector "[data-controller='toast']"
    assert_selector "[data-toast-duration-value='5000']"
  end

  test "accepts custom duration" do
    render_inline(ToastComponent.new(message: "메시지", duration: 3000))

    assert_selector "[data-toast-duration-value='3000']"
  end

  # --- Close button ---

  test "renders close button with dismiss action" do
    render_inline(ToastComponent.new(message: "메시지"))

    assert_selector "button[data-action='toast#dismiss']"
  end

  # --- Icon variants ---

  test "renders success icon" do
    render_inline(ToastComponent.new(type: :success, message: "성공"))

    html = page.native.inner_html
    assert_includes html, "text-green-500"
  end

  test "renders warning icon" do
    render_inline(ToastComponent.new(type: :warning, message: "경고"))

    html = page.native.inner_html
    assert_includes html, "text-amber-500"
  end

  test "renders danger icon" do
    render_inline(ToastComponent.new(type: :danger, message: "위험"))

    html = page.native.inner_html
    assert_includes html, "text-red-500"
  end

  test "renders info icon" do
    render_inline(ToastComponent.new(type: :info, message: "정보"))

    html = page.native.inner_html
    assert_includes html, "text-blue-500"
  end

  # --- Dark mode ---

  test "includes dark mode classes" do
    render_inline(ToastComponent.new(message: "메시지"))

    assert_selector "div[class*='dark:bg-slate-800']"
    assert_selector "div[class*='dark:border-slate-700']"
  end

  # --- Container classes ---

  test "includes background and border classes" do
    render_inline(ToastComponent.new(message: "메시지"))

    assert_selector "div[class*='bg-white']"
    assert_selector "div[class*='border']"
    assert_selector "div[class*='border-slate-200']"
    assert_selector "div[class*='px-4']"
    assert_selector "div[class*='py-3']"
  end

  # --- Action link ---

  test "renders action link when action_url and action_label provided" do
    render_inline(ToastComponent.new(
      message: "분석 완료",
      type: :success,
      action_url: "/properties/1/inspections/tabs/rights_analysis/edit",
      action_label: "결과 보기"
    ))

    assert_link "결과 보기", href: "/properties/1/inspections/tabs/rights_analysis/edit"
  end

  test "does not render action link when action_url is nil" do
    render_inline(ToastComponent.new(message: "일반 메시지"))

    assert_no_selector "a"
  end

  test "disables auto-dismiss when action_url is present" do
    render_inline(ToastComponent.new(
      message: "분석 완료",
      type: :success,
      action_url: "/results",
      action_label: "보기"
    ))

    assert_selector "[data-toast-duration-value='0']"
  end
end
