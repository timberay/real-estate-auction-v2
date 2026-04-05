# frozen_string_literal: true

require "test_helper"

class CompareTableComponentTest < ViewComponent::TestCase
  def default_diff
    [
      { label: "감정가", was: "1억", now: "1억 2천", delta: 20000000 },
      { label: "최저가", was: "8천만", now: "7천만", delta: -10000000 }
    ]
  end

  # --- Header ---

  test "renders header row with column titles" do
    render_inline(CompareTableComponent.new(diff: default_diff))

    assert_text "항목"
    assert_text "기존"
    assert_text "변경"
    assert_text "차이"
  end

  test "header has correct background" do
    render_inline(CompareTableComponent.new(diff: default_diff))

    html = page.native.inner_html
    assert_includes html, "bg-slate-50"
  end

  # --- Rows ---

  test "renders diff rows" do
    render_inline(CompareTableComponent.new(diff: default_diff))

    assert_text "감정가"
    assert_text "1억"
    assert_text "1억 2천"
    assert_text "최저가"
    assert_text "8천만"
    assert_text "7천만"
  end

  # --- Positive delta ---

  test "renders positive delta with green color and plus prefix" do
    render_inline(CompareTableComponent.new(diff: default_diff))

    assert_selector "span[class*='text-green-600']"
    assert_text "+"
  end

  # --- Negative delta ---

  test "renders negative delta with red color" do
    render_inline(CompareTableComponent.new(diff: default_diff))

    assert_selector "span[class*='text-red-600']"
  end

  # --- Tabular nums ---

  test "values use tabular-nums" do
    render_inline(CompareTableComponent.new(diff: default_diff))

    assert_selector "span[class*='tabular-nums']", minimum: 1
  end

  # --- Dark mode ---

  test "includes dark mode on header" do
    render_inline(CompareTableComponent.new(diff: default_diff))

    html = page.native.inner_html
    assert_includes html, "dark:bg-slate-800/80"
  end

  test "includes dark mode on positive delta" do
    render_inline(CompareTableComponent.new(diff: default_diff))

    assert_selector "span[class*='dark:text-green-400']"
  end

  test "includes dark mode on negative delta" do
    render_inline(CompareTableComponent.new(diff: default_diff))

    assert_selector "span[class*='dark:text-red-400']"
  end

  # --- Grid layout ---

  test "uses CSS grid with 4 columns" do
    render_inline(CompareTableComponent.new(diff: default_diff))

    assert_selector "div[class*='grid']"
    assert_selector "div[class*='grid-cols-4']"
  end
end
