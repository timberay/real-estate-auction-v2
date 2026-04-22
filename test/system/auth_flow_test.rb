require "application_system_test_case"

class AuthFlowTest < ApplicationSystemTestCase
  setup do
    mock_omniauth(:kakao, uid: "sys-1", email: "sys@kakao.test", name: "시스템유저")
  end

  test "guest can open modal, login with Kakao, and land back on the original page" do
    visit "/onboarding"
    click_on "로그인"
    assert_selector "turbo-frame#auth_modal"

    click_on "카카오로 계속하기"

    assert_text "환영합니다, 시스템유저님"
  end
end
