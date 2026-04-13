# frozen_string_literal: true

require "test_helper"

module Sidebar
  class ComponentTest < ViewComponent::TestCase
    # --- Basic rendering ---

    test "renders nav element" do
      render_inline(Sidebar::Component.new)

      assert_selector "nav"
    end

    test "renders nav with sidebar target" do
      render_inline(Sidebar::Component.new)

      assert_selector "nav[data-sidebar-target='sidebar']"
    end

    # --- Menu groups ---

    test "renders 3 group titles" do
      render_inline(Sidebar::Component.new)

      assert_text "물건검색"
      assert_text "리포트"
      assert_text "가이드"
    end

    test "renders group titles with dropdown controller" do
      render_inline(Sidebar::Component.new)

      assert_selector "[data-controller='dropdown']", count: 3
    end

    test "renders group toggle buttons" do
      render_inline(Sidebar::Component.new)

      assert_selector "[data-action='dropdown#toggle']", count: 3
    end

    test "renders dropdown menu targets" do
      render_inline(Sidebar::Component.new)

      assert_selector "[data-dropdown-target='menu']", count: 3
    end

    test "renders chevron targets" do
      render_inline(Sidebar::Component.new)

      assert_selector "[data-dropdown-target='chevron']", count: 3
    end

    # --- Menu items ---

    test "renders enabled menu item labels" do
      render_inline(Sidebar::Component.new)

      assert_text "예산 설정"
      assert_text "물건 목록"
      assert_text "AI분석"
    end

    test "renders disabled menu item labels" do
      render_inline(Sidebar::Component.new)

      assert_text "순수익 계산기"
      assert_text "리포트 내보내기"
      assert_text "명도 가이드"
    end

    test "renders enabled items as links" do
      render_inline(Sidebar::Component.new)

      assert_selector "a[href='/onboarding']", text: "예산 설정"
      assert_selector "a[href='/properties']", text: "물건 목록"
      assert_selector "a[href='/analyses/new']", text: "AI분석"
    end

    test "renders disabled items as disabled buttons" do
      render_inline(Sidebar::Component.new)

      assert_selector "button[disabled]", minimum: 3
    end

    test "renders disabled items with opacity" do
      render_inline(Sidebar::Component.new)

      assert_selector "button[disabled][class*='opacity-50']"
      assert_selector "button[disabled][class*='cursor-not-allowed']"
    end

    # --- Active item ---

    test "marks active item based on current_path" do
      render_inline(Sidebar::Component.new(current_path: "/onboarding"))

      assert_selector "a[href='/onboarding'][class*='bg-blue-50']"
      assert_selector "a[href='/onboarding'][class*='text-blue-700']"
      assert_selector "a[href='/onboarding'][class*='font-medium']"
    end

    test "marks properties path as active" do
      render_inline(Sidebar::Component.new(current_path: "/properties"))

      assert_selector "a[href='/properties'][class*='bg-blue-50']"
    end

    test "active item has dark mode classes" do
      render_inline(Sidebar::Component.new(current_path: "/onboarding"))

      assert_selector "a[href='/onboarding'][class*='dark:bg-blue-900/50']"
      assert_selector "a[href='/onboarding'][class*='dark:text-blue-400']"
    end

    # --- Toggle button ---

    test "renders toggle button with sidebar toggle action" do
      render_inline(Sidebar::Component.new)

      assert_selector "button[data-action='sidebar#toggle']"
    end

    test "renders toggle icon target" do
      render_inline(Sidebar::Component.new)

      assert_selector "[data-sidebar-target='toggleIcon']"
    end

    # --- Dark mode classes ---

    test "includes dark mode classes on nav" do
      render_inline(Sidebar::Component.new)

      assert_selector "nav[class*='dark:bg-slate-800']"
      assert_selector "nav[class*='dark:border-slate-700']"
    end

    # --- Nav structure ---

    test "renders nav with correct positioning" do
      render_inline(Sidebar::Component.new)

      assert_selector "nav[class*='fixed']"
      assert_selector "nav[class*='left-0']"
      assert_selector "nav[class*='top-16']"
      assert_selector "nav[class*='z-30']"
      assert_selector "nav[class*='w-64']"
    end

    test "renders nav with responsive visibility" do
      render_inline(Sidebar::Component.new)

      assert_selector "nav[class*='hidden']"
      assert_selector "nav[class*='md:block']"
    end

    test "renders border between content and toggle" do
      render_inline(Sidebar::Component.new)

      html = page.native.inner_html
      assert_includes html, "border-t"
    end
  end
end
