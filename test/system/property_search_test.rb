require "application_system_test_case"

class PropertySearchTest < ApplicationSystemTestCase
  setup do
    # Guest session is created automatically on first visit; no sign-in needed
    # budget_user fixture is non-guest but /search is accessible to all users
    visit root_path  # establish guest session
  end

  test "물건 목록 page renders region select and 조건검색 button" do
    visit search_path

    assert_selector "h1", text: "물건 목록", visible: false
    assert_selector "label", text: "관심 지역"
    assert_selector "button", text: "조건검색"
  end

  test "물건 목록 page does NOT show 사건번호 form or my-property cards" do
    visit search_path

    assert_no_selector "label", text: "사건번호로 물건 추가"
    assert_no_selector "#property-cards-grid"
  end
end
