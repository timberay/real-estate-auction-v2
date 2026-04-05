# frozen_string_literal: true

require "test_helper"

class StatCardComponentTest < ViewComponent::TestCase
  # --- Basic rendering ---

  test "renders label and value" do
    render_inline(StatCardComponent.new(label: "총 입찰 건수", value: "42"))

    assert_text "총 입찰 건수"
    assert_text "42"
  end

  # --- Primary variant (default) ---

  test "renders primary variant by default" do
    render_inline(StatCardComponent.new(label: "Label", value: "100"))

    assert_selector "div[class*='bg-blue-600']"
    assert_selector "div[class*='text-white']"
    assert_selector "div[class*='rounded-xl']"
    assert_selector "div[class*='p-6']"
    assert_selector "div[class*='text-center']"
    # Dark mode
    assert_selector "div[class*='dark:bg-blue-700']"
  end

  # --- Muted variant ---

  test "renders muted variant" do
    render_inline(StatCardComponent.new(label: "Label", value: "50", variant: :muted))

    assert_selector "div[class*='bg-slate-50']"
    assert_selector "div[class*='border']"
    assert_selector "div[class*='border-slate-200']"
    assert_selector "div[class*='rounded-lg']"
    assert_selector "div[class*='p-4']"
    # Dark mode
    assert_selector "div[class*='dark:bg-slate-800']"
    assert_selector "div[class*='dark:border-slate-700']"
  end

  # --- Sublabel ---

  test "renders sublabel when provided" do
    render_inline(StatCardComponent.new(label: "최고가", value: "1억", sublabel: "전월 대비 +5%"))

    assert_text "전월 대비 +5%"
  end

  test "does not render sublabel when not provided" do
    render_inline(StatCardComponent.new(label: "최고가", value: "1억"))

    html = page.native.inner_html
    # Only label and value should be present, no extra paragraph
    assert_no_selector "p:nth-child(3)"
  end
end
