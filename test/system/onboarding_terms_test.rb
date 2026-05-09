require "application_system_test_case"

class OnboardingTermsTest < ApplicationSystemTestCase
  setup do
    visit root_path  # establish guest session (no auth required for onboarding)
  end

  # Beg#2: step1 must use plain Korean instead of "유용자금"
  test "step1 shows plain '쓸 수 있는 현금' label instead of 유용자금" do
    visit start_onboarding_path

    assert_text "쓸 수 있는 현금"
    refute_text "유용자금"
  end

  test "step1 shows example instruments in helper text" do
    visit start_onboarding_path

    assert_text "예금"
  end

  # Beg#4: step3 must show LTV with an inline explainer tooltip
  test "step3 shows LTV tooltip button" do
    # Drive through step1 and step2 to reach step3
    visit start_onboarding_path
    fill_in "available_cash_display", with: "5000"
    find("button[type='submit']").click

    # step2: just submit defaults
    find("button[type='submit']").click

    # Now on step3
    assert_selector "[data-controller='tooltip']"
  end

  test "step3 LTV tooltip reveals explanation when clicked" do
    visit start_onboarding_path
    fill_in "available_cash_display", with: "5000"
    find("button[type='submit']").click
    find("button[type='submit']").click

    find("[data-controller='tooltip'] button").click
    assert_text "집값 대비 빌릴 수 있는 비율"
  end

  # Regression guard: no user-facing view or component must contain "유용자금"
  test "no '유용자금' string in user-facing views or components" do
    views = Dir.glob(Rails.root.join("app/views/**/*.{erb,html}").to_s)
    views += Dir.glob(Rails.root.join("app/components/**/*.{rb,erb,html}").to_s)
    offenders = views.reject { |f| f.include?("/test/") }.select { |f| File.read(f).include?("유용자금") }
    assert_empty offenders, "Files still contain '유용자금': #{offenders.join(', ')}"
  end
end
