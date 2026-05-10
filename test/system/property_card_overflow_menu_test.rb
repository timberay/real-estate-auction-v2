require "application_system_test_case"

# B29: 카드 카드 우하단의 삭제 버튼이 더보기(overflow) 메뉴 안에 숨겨지고,
# 메뉴 외부 클릭 시 닫히는지 확인.
class PropertyCardOverflowMenuTest < ApplicationSystemTestCase
  setup do
    @user = users(:budget_user)
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: @user, property: @property)
    sign_in_as(@user)
  end

  test "delete button is hidden behind overflow menu, opens on click, closes on outside click" do
    visit properties_path

    card = find("##{ActionView::RecordIdentifier.dom_id(@property, :card)}")

    within card do
      # 메뉴는 hidden 상태로 시작 — 삭제 버튼은 보이지 않아야 함.
      assert_selector "[data-overflow-menu-target='menu'][hidden]", visible: :all
      assert_no_button "삭제"

      trigger = find("[data-overflow-menu-target='trigger']")
      assert_equal "false", trigger["aria-expanded"]

      # 더보기 버튼 클릭 → 메뉴 열림, 삭제 버튼 노출.
      trigger.click
      assert_selector "[data-overflow-menu-target='menu']:not([hidden])"
      assert_button "삭제"
      assert_equal "true", trigger["aria-expanded"]
    end

    # 카드 바깥 클릭 → 메뉴 닫힘.
    find("body").click

    within card do
      assert_selector "[data-overflow-menu-target='menu'][hidden]", visible: :all
      assert_no_button "삭제"
    end
  end
end
