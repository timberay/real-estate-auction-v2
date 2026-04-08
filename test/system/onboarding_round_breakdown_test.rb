require "application_system_test_case"

class OnboardingRoundBreakdownTest < ApplicationSystemTestCase
  test "round breakdown table updates dynamically with failed auction rounds slider" do
    # Step 1: enter available cash and submit
    visit start_onboarding_path
    find("[data-number-format-target='display']").fill_in with: "50000"
    find("button[type='submit']").click

    # Step 2: submit with auto-calculated reserves
    assert_text "예비비 설정"
    find("button[type='submit']").click

    # Step 3: now on loan & bid settings page
    assert_text "대출 및 낙찰가 설정"
    assert_selector "[data-loan-slider-target='roundBreakdown']"

    # Set rounds to 0 — should show 신건 기준
    execute_script("const el = document.querySelector(\"input[name='budget_setting[failed_auction_rounds]']\"); el.value = 0; el.dispatchEvent(new Event('input'))")

    within("[data-loan-slider-target='roundBreakdown']") do
      assert_text "신건 기준"
      assert_text "감정가"
      assert_no_text "유찰 → 최저가"
    end

    # Set rounds to 3 — should show all round rows
    execute_script("const el = document.querySelector(\"input[name='budget_setting[failed_auction_rounds]']\"); el.value = 3; el.dispatchEvent(new Event('input'))")

    within("[data-loan-slider-target='roundBreakdown']") do
      assert_text "유찰 3회차 기준"
      assert_text "감정가"
      assert_text "1회 유찰 → 최저가"
      assert_text "2회 유찰 → 최저가"
      assert_text "3회 유찰 → 최저가"
    end
  end
end
