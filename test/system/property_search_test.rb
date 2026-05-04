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

  test "검색 결과 카드 — 이미 내 물건에 추가된 항목은 '이미 추가됨' 배지로 표시되고 클릭 비활성화" do
    visit search_path
    user = User.last  # the just-created guest from setup's visit root_path

    property = Property.create!(case_number: "2024타경9999", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 100_000_000, min_bid_price: 80_000_000)
    user.user_properties.create!(property: property)
    user.search_results.create!(case_number: "2024타경9999", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 100_000_000, min_bid_price: 80_000_000)
    user.search_results.create!(case_number: "2024타경0000", court_code: "B000210", court_name: "서울지법", address: "주소2", appraisal_price: 100_000_000, min_bid_price: 80_000_000)

    visit search_path

    within "##{dom_id(user.search_results.find_by(case_number: '2024타경9999'), :inline)}" do
      assert_text "이미 추가됨"
      assert_no_selector "button[type='submit']"
    end
    within "##{dom_id(user.search_results.find_by(case_number: '2024타경0000'), :inline)}" do
      assert_no_text "이미 추가됨"
      assert_selector "button[type='submit']"
    end
  end
end
