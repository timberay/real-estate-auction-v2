require "application_system_test_case"

class MyPropertiesTest < ApplicationSystemTestCase
  setup do
    visit root_path  # establish guest session (project doesn't have sign_in_as helper)
  end

  test "내 물건 page renders 사건번호 form and property cards grid" do
    visit properties_path

    assert_selector "label", text: "사건번호로 물건 추가"
    assert_selector "#property-cards-grid"
  end

  test "내 물건 page does NOT show region select / 조건검색 / criteria-search-results" do
    visit properties_path

    assert_no_selector "label", text: "관심 지역"
    assert_no_selector "button", text: "조건검색"
    assert_no_selector "#criteria-search-results"
  end

  test "내 물건 page does NOT show inline budget box (moved to header)" do
    visit properties_path

    # Header has the budget link with 최대입찰가, but inside main content area there should be none
    within "main" do
      assert_no_selector "a[href='/settings/budget']", text: /최대입찰가/
    end
  end
end
