require "application_system_test_case"

class LandingTest < ApplicationSystemTestCase
  test "unauthenticated visitor sees landing instead of being bounced to onboarding" do
    visit root_path
    assert_text "법원 경매 권리분석 도구"
    assert_link "체험 시작하기"
    assert_link "로그인"
    assert_no_current_path(/\/onboarding/)
  end

  test "logged-in onboarded user goes to /properties" do
    sign_in_as users(:budget_user)
    visit root_path
    assert_current_path "/properties"
  end

  test "logged-in non-onboarded user goes to onboarding" do
    sign_in_as users(:guest)
    visit root_path
    assert_match %r{/onboarding}, current_path
  end
end
