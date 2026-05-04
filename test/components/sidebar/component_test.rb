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

    test "renders menu groups without group titles" do
      render_inline(Sidebar::Component.new)

      assert_no_text "물건검색"
      # "가이드" appears in menu item "명도 가이드", so check no standalone group header exists
      assert_no_selector "[data-sidebar-group]"
    end

    test "renders all menu items without dropdown collapse" do
      render_inline(Sidebar::Component.new)

      assert_no_selector "[data-controller='dropdown']"
      assert_no_selector "[data-action='dropdown#toggle']"
    end

    # --- Menu items ---

    test "renders enabled menu item labels" do
      render_inline(Sidebar::Component.new)

      assert_text "예산 설정"
      assert_text "물건 목록"
      assert_text "내 물건"
      assert_text "AI 분석"
    end

    test "does not render removed report menu items" do
      render_inline(Sidebar::Component.new)

      assert_no_text "순수익 계산기"
      assert_no_text "리포트 내보내기"
    end

    test "renders eviction guide as enabled links" do
      render_inline(Sidebar::Component.new)

      assert_selector "a[href='/eviction_guide']", text: "명도 가이드"
      assert_selector "a[href='/eviction_guide/simulator']", text: "명도 시뮬레이터"
    end

    test "renders enabled items as links" do
      render_inline(Sidebar::Component.new)

      assert_selector "a[href='/onboarding']", text: "예산 설정"
      assert_selector "a[href='/search']", text: "물건 목록"
      assert_selector "a[href='/properties']", text: "내 물건"
      assert_selector "a[href='/analyses/new']", text: "AI 분석"
    end

    test "renders no disabled buttons" do
      render_inline(Sidebar::Component.new)

      assert_no_selector "button[disabled]"
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

      assert_selector "a[href='/properties'][class*='bg-blue-50']", text: "내 물건"
    end

    test "marks search path as active for /search" do
      render_inline(Sidebar::Component.new(current_path: "/search"))

      assert_selector "a[href='/search'][class*='bg-blue-50']", text: "물건 목록"
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

    # --- 시작하기 group ---

    test "renders 사용자매뉴얼 menu item" do
      render_inline(Sidebar::Component.new)

      assert_text "사용자매뉴얼"
      assert_selector "a[href='/manual']", text: "사용자매뉴얼"
    end

    test "사용자매뉴얼 is the first link in the sidebar (시작하기 group is at top)" do
      render_inline(Sidebar::Component.new)

      first_link = page.first("a[href]")
      assert_equal "/manual", first_link[:href]
    end

    test "marks 사용자매뉴얼 as active when on /manual" do
      render_inline(Sidebar::Component.new(current_path: "/manual"))

      assert_selector "a[href='/manual'][class*='bg-blue-50']"
    end
  end
end
