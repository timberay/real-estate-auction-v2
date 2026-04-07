# frozen_string_literal: true

require "test_helper"

class ButtonComponentTest < ViewComponent::TestCase
  # --- Variant tests ---

  test "renders primary variant with correct classes" do
    render_inline(ButtonComponent.new(variant: :primary)) { "Click me" }

    assert_selector "button", text: "Click me"
    assert_selector "button.bg-blue-600"
    assert_selector "button[class*='hover:bg-blue-700']"
    assert_selector "button[class*='text-white']"
    # Dark mode
    assert_selector "button[class*='dark:bg-blue-500']"
    assert_selector "button[class*='dark:hover:bg-blue-400']"
  end

  test "renders secondary variant with correct classes" do
    render_inline(ButtonComponent.new(variant: :secondary)) { "Secondary" }

    assert_selector "button.bg-slate-100"
    assert_selector "button[class*='hover:bg-slate-200']"
    assert_selector "button[class*='text-slate-700']"
    # Dark mode
    assert_selector "button[class*='dark:bg-slate-700']"
    assert_selector "button[class*='dark:hover:bg-slate-600']"
    assert_selector "button[class*='dark:text-slate-200']"
  end

  test "renders outline variant with correct classes" do
    render_inline(ButtonComponent.new(variant: :outline)) { "Outline" }

    assert_selector "button[class*='border']"
    assert_selector "button[class*='border-slate-200']"
    assert_selector "button[class*='hover:bg-slate-50']"
    assert_selector "button[class*='text-slate-700']"
    # Dark mode
    assert_selector "button[class*='dark:border-slate-600']"
    assert_selector "button[class*='dark:hover:bg-slate-700']"
    assert_selector "button[class*='dark:text-slate-200']"
  end

  test "renders danger variant with correct classes" do
    render_inline(ButtonComponent.new(variant: :danger)) { "Delete" }

    assert_selector "button.bg-red-600"
    assert_selector "button[class*='hover:bg-red-700']"
    assert_selector "button[class*='text-white']"
    # Dark mode
    assert_selector "button[class*='dark:bg-red-500']"
    assert_selector "button[class*='dark:hover:bg-red-400']"
  end

  test "renders ghost variant with correct classes" do
    render_inline(ButtonComponent.new(variant: :ghost)) { "Ghost" }

    assert_selector "button[class*='hover:bg-slate-100']"
    assert_selector "button[class*='text-slate-600']"
    # Dark mode
    assert_selector "button[class*='dark:hover:bg-slate-700']"
    assert_selector "button[class*='dark:text-slate-300']"
  end

  test "renders link variant with correct classes" do
    render_inline(ButtonComponent.new(variant: :link)) { "Link" }

    assert_selector "button[class*='text-blue-600']"
    assert_selector "button[class*='hover:text-blue-700']"
    assert_selector "button[class*='underline-offset-4']"
    assert_selector "button[class*='hover:underline']"
    # Dark mode
    assert_selector "button[class*='dark:text-blue-400']"
    assert_selector "button[class*='dark:hover:text-blue-300']"
  end

  # --- Size tests ---

  test "renders sm size with correct classes" do
    render_inline(ButtonComponent.new(size: :sm)) { "Small" }

    assert_selector "button.px-3"
    assert_selector "button[class*='h-8']"
    assert_selector "button[class*='text-xs']"
  end

  test "renders md size with correct classes (default)" do
    render_inline(ButtonComponent.new) { "Medium" }

    assert_selector "button.px-4"
    assert_selector "button[class*='h-10']"
    assert_selector "button[class*='text-sm']"
  end

  test "renders lg size with correct classes" do
    render_inline(ButtonComponent.new(size: :lg)) { "Large" }

    assert_selector "button.px-6"
    assert_selector "button[class*='h-12']"
    assert_selector "button[class*='text-base']"
  end

  # --- Disabled state ---

  test "renders disabled state with correct classes and attribute" do
    render_inline(ButtonComponent.new(disabled: true)) { "Disabled" }

    assert_selector "button[disabled]"
    assert_selector "button[class*='opacity-50']"
    assert_selector "button[class*='cursor-not-allowed']"
    assert_selector "button[class*='pointer-events-none']"
  end

  # --- Icon support ---

  test "renders icon before text" do
    render_inline(ButtonComponent.new(icon: "plus")) { "Add" }

    assert_selector "button svg"
    assert_selector "button", text: "Add"
  end

  test "renders sm icon with w-4 h-4 classes" do
    render_inline(ButtonComponent.new(icon: "plus", size: :sm)) { "Add" }

    assert_selector "button svg[class*='w-4']"
    assert_selector "button svg[class*='h-4']"
  end

  test "renders md icon with w-5 h-5 classes" do
    render_inline(ButtonComponent.new(icon: "plus", size: :md)) { "Add" }

    assert_selector "button svg[class*='w-5']"
    assert_selector "button svg[class*='h-5']"
  end

  # --- Tag :a with href ---

  test "renders as anchor tag when tag is :a" do
    render_inline(ButtonComponent.new(tag: :a, href: "/path")) { "Link" }

    assert_selector "a[href='/path']", text: "Link"
    assert_no_selector "button"
  end

  # --- Focus ring ---

  test "includes focus ring classes" do
    render_inline(ButtonComponent.new) { "Focus" }

    assert_selector "button[class*='focus-visible:ring-2']"
    assert_selector "button[class*='focus-visible:ring-blue-500/50']"
    assert_selector "button[class*='focus-visible:ring-offset-2']"
    # Dark focus ring
    assert_selector "button[class*='dark:focus-visible:ring-blue-400/50']"
    assert_selector "button[class*='dark:focus-visible:ring-offset-slate-900']"
  end

  # --- Custom classes ---

  test "accepts additional classes via html_options" do
    render_inline(ButtonComponent.new(class: "w-full justify-center")) { "Full" }

    assert_selector "button.w-full"
    assert_selector "button[class*='justify-center']"
  end

  # --- Common classes ---

  test "includes common classes" do
    render_inline(ButtonComponent.new) { "Common" }

    assert_selector "button[class*='font-medium']"
    assert_selector "button[class*='rounded-md']"
    assert_selector "button[class*='transition-colors']"
    assert_selector "button[class*='duration-150']"
    assert_selector "button[class*='inline-flex']"
    assert_selector "button[class*='items-center']"
    assert_selector "button[class*='gap-2']"
  end
end
