require "application_system_test_case"

class ManualsTest < ApplicationSystemTestCase
  test "신규 사용자가 사이드바에서 사용자매뉴얼을 열면 hero와 step 1이 펼쳐져 있다" do
    visit "/onboarding"  # bootstraps a guest session (lazy guest creation)
    visit "/manual"

    assert_text "경매 초보의 워크북"
    assert_text "낙찰 전 89개 체크리스트, 낙찰 후 명도 시뮬레이터"

    # current_step = budget (1번) for fresh user
    pre_section = find(:xpath, "//section[.//h2[normalize-space()='낙찰 전']]")
    within(pre_section) do
      assert_selector "details[open]", text: "예산 정하기"
    end

    # Continue card CTA points to onboarding
    assert_selector "a[href='/onboarding']", text: "예산 설정 시작"
  end

  test "사이드바 사용자매뉴얼 클릭 시 /manual로 이동한다" do
    visit "/onboarding"  # bootstraps a guest session
    visit "/properties"

    click_on "사용자매뉴얼"

    assert_current_path "/manual"
    assert_text "경매 초보의 워크북"
  end

  test "예산을 완료한 사용자는 step 2가 펼쳐져 있다" do
    visit "/onboarding"  # bootstraps a guest session
    user = User.last  # the just-created guest
    BudgetSetting.create!(user: user, available_cash: 30_000, loan_ratio: 0.7, completed_at: Time.current)

    visit "/manual"

    pre_section = find(:xpath, "//section[.//h2[normalize-space()='낙찰 전']]")
    within(pre_section) do
      assert_selector "details[open]", text: "물건 찾기"
    end
  end
end
