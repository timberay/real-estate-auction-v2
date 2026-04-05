# frozen_string_literal: true

require "test_helper"

class CardComponentTest < ViewComponent::TestCase
  # --- Body content ---

  test "renders body content" do
    render_inline(CardComponent.new) { "Body content here" }

    assert_selector "div[class*='rounded-lg']", text: "Body content here"
    assert_selector "div[class*='bg-white']"
    assert_selector "div[class*='shadow-sm']"
  end

  # --- Title ---

  test "renders with title" do
    render_inline(CardComponent.new(title: "Card Title")) { "Body" }

    assert_selector "h3[class*='text-lg']", text: "Card Title"
    assert_selector "h3[class*='font-semibold']"
    assert_text "Body"
  end

  # --- Title + Description ---

  test "renders with title and description" do
    render_inline(CardComponent.new(title: "Title", description: "A description")) { "Body" }

    assert_selector "h3", text: "Title"
    assert_selector "p[class*='text-sm']", text: "A description"
    assert_selector "p[class*='text-slate-600']"
    assert_text "Body"
  end

  # --- Footer slot ---

  test "renders footer slot" do
    render_inline(CardComponent.new) do |card|
      card.with_footer { "Footer content" }
      "Body content"
    end

    assert_text "Body content"
    assert_text "Footer content"
    assert_selector "div[class*='border-t']", text: "Footer content"
    assert_selector "div[class*='bg-slate-50/50']", text: "Footer content"
  end

  # --- Dark mode classes ---

  test "includes dark mode classes on container" do
    render_inline(CardComponent.new) { "Content" }

    assert_selector "div[class*='dark:bg-slate-800']"
    assert_selector "div[class*='dark:border-slate-700']"
  end

  test "includes dark mode classes on header" do
    render_inline(CardComponent.new(title: "Title")) { "Content" }

    # Header border dark mode
    html = page.native.inner_html
    assert_includes html, "dark:border-slate-700"
    # Title dark mode
    assert_selector "h3[class*='dark:text-slate-100']"
  end

  test "includes dark mode classes on description" do
    render_inline(CardComponent.new(title: "T", description: "Desc")) { "Content" }

    assert_selector "p[class*='dark:text-slate-400']"
  end

  test "includes dark mode classes on footer" do
    render_inline(CardComponent.new) do |card|
      card.with_footer { "Footer" }
      "Body"
    end

    html = page.native.inner_html
    assert_includes html, "dark:border-slate-700"
    assert_includes html, "dark:bg-slate-800/50"
  end

  # --- Custom classes ---

  test "accepts additional classes via html_options" do
    render_inline(CardComponent.new(class: "mt-4")) { "Content" }

    assert_selector "div.mt-4"
  end

  # --- Header border ---

  test "header has bottom border" do
    render_inline(CardComponent.new(title: "Title")) { "Content" }

    html = page.native.inner_html
    assert_includes html, "border-b"
  end

  # --- No header when no title ---

  test "does not render header when no title" do
    render_inline(CardComponent.new) { "Content" }

    assert_no_selector "h3"
  end
end
