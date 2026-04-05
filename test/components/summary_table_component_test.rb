# frozen_string_literal: true

require "test_helper"

class SummaryTableComponentTest < ViewComponent::TestCase
  # --- Basic rendering ---

  test "renders rows with label and value" do
    rows = [
      { label: "감정가", value: "1억 5,000만원" },
      { label: "최저가", value: "1억 2,000만원" }
    ]
    render_inline(SummaryTableComponent.new(rows: rows))

    assert_text "감정가"
    assert_text "1억 5,000만원"
    assert_text "최저가"
    assert_text "1억 2,000만원"
  end

  # --- Container ---

  test "renders container with correct styling" do
    rows = [{ label: "항목", value: "값" }]
    render_inline(SummaryTableComponent.new(rows: rows))

    assert_selector "div[class*='bg-white']"
    assert_selector "div[class*='border']"
    assert_selector "div[class*='border-slate-200']"
    assert_selector "div[class*='rounded-lg']"
    assert_selector "div[class*='overflow-hidden']"
  end

  # --- Title ---

  test "renders title when provided" do
    rows = [{ label: "항목", value: "값" }]
    render_inline(SummaryTableComponent.new(rows: rows, title: "요약 정보"))

    assert_selector "h2", text: "요약 정보"
    html = page.native.inner_html
    assert_includes html, "bg-slate-50"
  end

  test "does not render title when not provided" do
    rows = [{ label: "항목", value: "값" }]
    render_inline(SummaryTableComponent.new(rows: rows))

    assert_no_selector "h2"
  end

  # --- Highlighted rows ---

  test "renders highlighted row with special styling" do
    rows = [
      { label: "일반", value: "100" },
      { label: "중요", value: "200", highlight: true }
    ]
    render_inline(SummaryTableComponent.new(rows: rows))

    html = page.native.inner_html
    assert_includes html, "font-semibold"
  end

  # --- Row structure ---

  test "rows have flex layout with justify-between" do
    rows = [{ label: "항목", value: "값" }]
    render_inline(SummaryTableComponent.new(rows: rows))

    assert_selector "div[class*='flex']"
    assert_selector "div[class*='justify-between']"
    assert_selector "div[class*='px-4']"
    assert_selector "div[class*='py-3']"
  end

  # --- Tabular nums ---

  test "values use tabular-nums" do
    rows = [{ label: "항목", value: "100" }]
    render_inline(SummaryTableComponent.new(rows: rows))

    assert_selector "span[class*='tabular-nums']"
  end

  # --- Dark mode ---

  test "includes dark mode classes on container" do
    rows = [{ label: "항목", value: "값" }]
    render_inline(SummaryTableComponent.new(rows: rows))

    assert_selector "div[class*='dark:bg-slate-800']"
    assert_selector "div[class*='dark:border-slate-700']"
  end

  test "includes dark mode classes on title" do
    rows = [{ label: "항목", value: "값" }]
    render_inline(SummaryTableComponent.new(rows: rows, title: "제목"))

    html = page.native.inner_html
    assert_includes html, "dark:bg-slate-800/80"
  end

  # --- Divide-y ---

  test "rows section has divide-y" do
    rows = [
      { label: "항목1", value: "값1" },
      { label: "항목2", value: "값2" }
    ]
    render_inline(SummaryTableComponent.new(rows: rows))

    assert_selector "div[class*='divide-y']"
  end
end
