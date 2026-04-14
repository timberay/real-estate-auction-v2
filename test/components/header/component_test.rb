# frozen_string_literal: true

require "test_helper"

module Header
  class ComponentTest < ViewComponent::TestCase
    # --- Basic rendering ---

    test "renders header element" do
      render_inline(Header::Component.new)

      assert_selector "header"
    end

    test "renders app name" do
      render_inline(Header::Component.new)

      assert_text "Real Estate Auction"
    end

    test "renders custom app name" do
      render_inline(Header::Component.new(app_name: "Custom App"))

      assert_text "Custom App"
    end

    test "renders app name with correct classes" do
      render_inline(Header::Component.new)

      assert_selector "span.font-bold", text: "Real Estate Auction"
      assert_selector "span[class*='text-lg']"
      assert_selector "span[class*='text-white']"
    end

    # --- Header layout ---

    test "renders header with fixed positioning and z-index" do
      render_inline(Header::Component.new)

      assert_selector "header[class*='fixed']"
      assert_selector "header[class*='top-0']"
      assert_selector "header[class*='z-40']"
      assert_selector "header[class*='h-16']"
    end

    test "renders header with flex layout" do
      render_inline(Header::Component.new)

      assert_selector "header[class*='flex']"
      assert_selector "header[class*='items-center']"
      assert_selector "header[class*='justify-between']"
    end

    # --- Hamburger button ---

    test "renders hamburger button with md:hidden" do
      render_inline(Header::Component.new)

      assert_selector "button[class*='md:hidden']"
    end

    test "renders hamburger button with sidebar toggle action" do
      render_inline(Header::Component.new)

      assert_selector "button[data-action='sidebar#toggleMobile']"
    end

    # --- Dark mode toggle ---

    test "renders dark mode toggle controller" do
      render_inline(Header::Component.new)

      assert_selector "[data-controller='dark-mode']"
    end

    test "renders dark mode toggle button" do
      render_inline(Header::Component.new)

      assert_selector "[data-action='dark-mode#toggle']"
    end

    test "renders sun and moon icon targets" do
      render_inline(Header::Component.new)

      assert_selector "[data-dark-mode-target='sunIcon']"
      assert_selector "[data-dark-mode-target='moonIcon']"
    end

    # --- Dark mode classes ---

    test "includes dark mode classes on header" do
      render_inline(Header::Component.new)

      assert_selector "header[class*='bg-slate-800']"
      assert_selector "header[class*='dark:bg-slate-900']"
    end

    # --- Right side buttons ---

    test "renders notification bell button" do
      render_inline(Header::Component.new)

      html = page.native.inner_html
      assert_includes html, "svg"
    end

    test "renders buttons with correct styling" do
      render_inline(Header::Component.new)

      assert_selector "button[class*='p-2']"
      assert_selector "button[class*='rounded-md']"
      assert_selector "button[class*='text-slate-300']"
    end

    # --- Analysis indicator ---

    test "renders analysis indicator placeholder" do
      render_inline(Header::Component.new)

      assert_selector "span#analysis_indicator"
    end
  end
end
