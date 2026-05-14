# frozen_string_literal: true

require "test_helper"

module Header
  class ComponentTest < ViewComponent::TestCase
    # --- Basic rendering ---

    test "renders header element" do
      render_inline(Header::Component.new)

      assert_selector "header"
    end

    test "renders app name in Korean" do
      render_inline(Header::Component.new)

      assert_text "부동산 경매 도우미"
    end

    test "renders custom app name" do
      render_inline(Header::Component.new(app_name: "Custom App"))

      assert_text "Custom App"
    end

    test "renders app name with correct classes" do
      render_inline(Header::Component.new)

      assert_selector "span.font-bold", text: "부동산 경매 도우미"
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

    test "does not render notification or user menu buttons" do
      render_inline(Header::Component.new)

      assert_no_selector "button[aria-label='알림']"
      assert_no_selector "button[aria-label='사용자 메뉴']"
    end

    test "renders only hamburger and dark mode buttons" do
      render_inline(Header::Component.new)

      # hamburger + dark-mode toggle = 2 buttons in the header
      assert_selector "button[aria-label='메뉴 열기']"
      assert_selector "button[aria-label='다크 모드 전환']"
    end

    # --- Analysis indicator ---

    test "renders analysis indicator placeholder" do
      render_inline(Header::Component.new)

      assert_selector "span#analysis_indicator"
    end

    # --- Budget indicator ---

    test "renders budget indicator with max bid when budget set" do
      user = users(:budget_user)
      user.create_budget_setting!(max_bid_amount: 50_000) unless user.budget_setting
      user.budget_setting.update!(max_bid_amount: 50_000)

      render_inline(Header::Component.new(current_user: user))

      assert_selector "a[href='/settings/budget']", text: /최대입찰가/
      assert_text "5억"
    end

    # --- Notification bell ---

    test "renders notification bell link to /notifications when current_user present" do
      user = users(:budget_user)
      render_inline(Header::Component.new(current_user: user))

      assert_selector "a[href='/notifications'][aria-label*='알림']"
    end

    test "notification badge shows unread count" do
      user = users(:budget_user)
      user.notifications.create!(kind: "x", title: "unread 1")
      user.notifications.create!(kind: "x", title: "unread 2")
      user.notifications.create!(kind: "x", title: "read", read_at: Time.current)

      render_inline(Header::Component.new(current_user: user))

      assert_selector "#notification_badge", text: "2"
    end

    test "notification badge hides count when zero unread" do
      user = users(:budget_user)
      user.notifications.create!(kind: "x", title: "all read", read_at: Time.current)

      render_inline(Header::Component.new(current_user: user))

      # Badge container exists (for turbo replace target) but no visible number
      assert_selector "#notification_badge"
      refute_selector "#notification_badge span[aria-label*='새 알림']"
    end

    test "subscribes to user notifications Turbo channel when current_user present" do
      user = users(:budget_user)
      render_inline(Header::Component.new(current_user: user))

      assert_selector "turbo-cable-stream-source", visible: :all
    end

    test "no bell rendered when current_user is nil" do
      render_inline(Header::Component.new(current_user: nil))

      assert_no_selector "a[href='/notifications']"
    end

    test "renders budget unset link when no budget" do
      user = users(:budget_user)
      user.budget_setting&.destroy
      user.reload

      render_inline(Header::Component.new(current_user: user))

      assert_selector "a[href='/settings/budget']", text: "예산 미설정"
    end

    test "header exposes a help link to the manual so first-time users can reach guidance (C16)" do
      render_inline(Header::Component.new)

      # C16: a persistent "도움말" link keeps the FAQ/manual reachable from
      # every page — not just for users who happen to open the sidebar.
      assert_selector "header a[href='/manual']", text: /도움말/
    end

    test "budget indicator is hidden on mobile and shown from md: up (C7)" do
      user = users(:budget_user)
      user.create_budget_setting!(max_bid_amount: 50_000) unless user.budget_setting
      user.budget_setting.update!(max_bid_amount: 50_000)

      render_inline(Header::Component.new(current_user: user))

      # The header budget link must be hidden when the hamburger button is
      # visible (< md). Mobile users see the indicator inside the sidebar
      # after opening the menu. Using the same md: breakpoint as the
      # hamburger keeps the two views mutually exclusive.
      link = page.find("a[href='/settings/budget']", text: /최대입찰가/)
      wrapper = link.find(:xpath, "ancestor::*[contains(@class, 'md:inline-flex') or contains(@class, 'md:flex') or contains(@class, 'md:block')][1]")
      assert_includes wrapper[:class], "hidden",
        "expected header budget indicator wrapper to be hidden on mobile"
    end
  end

  class RouteHelpersTest < ActiveSupport::TestCase
    test "header component template uses named route helpers for auth and settings" do
      template = File.read(Rails.root.join("app/components/header/component.html.erb"))
      refute_match(%r{button_to[^,]+,\s*"/auth/logout"}, template, "use auth_logout_path helper")
      refute_match(%r{link_to[^,]+,\s*"/auth/login"}, template, "use auth_login_path helper")
      refute_match(%r{link_to[^,]+,\s*"/settings/budget"}, template, "use settings_budget_path helper")
      assert_match(/auth_login_path/, template)
      assert_match(/auth_logout_path/, template)
      assert_match(/settings_budget_path/, template)
    end
  end
end
