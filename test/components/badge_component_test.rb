# frozen_string_literal: true

require "test_helper"

class BadgeComponentTest < ViewComponent::TestCase
  # --- Variant tests ---

  test "renders default variant with correct classes" do
    render_inline(BadgeComponent.new) { "Default" }

    assert_selector "span", text: "Default"
    assert_selector "span.bg-slate-100"
    assert_selector "span[class*='text-slate-700']"
    # Dark mode
    assert_selector "span[class*='dark:bg-slate-700']"
    assert_selector "span[class*='dark:text-slate-300']"
  end

  test "renders success variant with correct classes" do
    render_inline(BadgeComponent.new(variant: :success)) { "Success" }

    assert_selector "span[class*='bg-green-200']"
    assert_selector "span[class*='text-green-800']"
    assert_selector "span[class*='ring-1']"
    assert_selector "span[class*='ring-inset']"
    assert_selector "span[class*='ring-green-600/20']"
    # Dark mode
    assert_selector "span[class*='dark:bg-green-900/30']"
    assert_selector "span[class*='dark:text-green-400']"
    assert_selector "span[class*='dark:ring-green-400/20']"
  end

  test "renders warning variant with correct classes" do
    render_inline(BadgeComponent.new(variant: :warning)) { "Warning" }

    assert_selector "span[class*='bg-yellow-200']"
    assert_selector "span[class*='text-yellow-800']"
    assert_selector "span[class*='ring-1']"
    assert_selector "span[class*='ring-inset']"
    assert_selector "span[class*='ring-yellow-600/20']"
    # Dark mode
    assert_selector "span[class*='dark:bg-yellow-900/30']"
    assert_selector "span[class*='dark:text-yellow-400']"
    assert_selector "span[class*='dark:ring-yellow-400/20']"
  end

  test "renders danger variant with correct classes" do
    render_inline(BadgeComponent.new(variant: :danger)) { "Danger" }

    assert_selector "span[class*='bg-red-200']"
    assert_selector "span[class*='text-red-800']"
    assert_selector "span[class*='ring-1']"
    assert_selector "span[class*='ring-inset']"
    assert_selector "span[class*='ring-red-600/20']"
    # Dark mode
    assert_selector "span[class*='dark:bg-red-900/30']"
    assert_selector "span[class*='dark:text-red-400']"
    assert_selector "span[class*='dark:ring-red-400/20']"
  end

  test "renders info variant with correct classes" do
    render_inline(BadgeComponent.new(variant: :info)) { "Info" }

    assert_selector "span[class*='bg-blue-200']"
    assert_selector "span[class*='text-blue-800']"
    assert_selector "span[class*='ring-1']"
    assert_selector "span[class*='ring-inset']"
    assert_selector "span[class*='ring-blue-600/20']"
    # Dark mode
    assert_selector "span[class*='dark:bg-blue-900/30']"
    assert_selector "span[class*='dark:text-blue-400']"
    assert_selector "span[class*='dark:ring-blue-400/20']"
  end

  test "renders accent variant with correct classes" do
    render_inline(BadgeComponent.new(variant: :accent)) { "Accent" }

    assert_selector "span[class*='bg-amber-200']"
    assert_selector "span[class*='text-amber-800']"
    assert_selector "span[class*='ring-1']"
    assert_selector "span[class*='ring-inset']"
    assert_selector "span[class*='ring-amber-600/20']"
    # Dark mode
    assert_selector "span[class*='dark:bg-amber-900/30']"
    assert_selector "span[class*='dark:text-amber-400']"
    assert_selector "span[class*='dark:ring-amber-400/20']"
  end

  # --- Common classes ---

  test "includes common badge classes" do
    render_inline(BadgeComponent.new) { "Badge" }

    assert_selector "span[class*='inline-flex']"
    assert_selector "span[class*='items-center']"
    assert_selector "span[class*='rounded-full']"
    assert_selector "span[class*='px-2.5']"
    assert_selector "span[class*='py-1']"
    assert_selector "span[class*='text-sm']"
    assert_selector "span[class*='font-medium']"
  end

  # --- Custom classes ---

  test "accepts additional classes via html_options" do
    render_inline(BadgeComponent.new(class: "ml-2")) { "Custom" }

    assert_selector "span.ml-2"
  end
end
