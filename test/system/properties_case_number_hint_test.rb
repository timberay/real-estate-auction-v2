require "application_system_test_case"

# B18 / UX-audit B-8: case-number form should explain WHERE to find a 사건번호 and
# offer a shortcut for users who don't have one yet.
class PropertiesCaseNumberHintTest < ApplicationSystemTestCase
  setup do
    @user = users(:budget_user)
    sign_in_as(@user)
  end

  test "case-number form shows courtauction.go.kr source link and 조건검색 shortcut" do
    visit properties_path

    # External hint: where to look up a 사건번호.
    assert_selector "a[href='https://www.courtauction.go.kr']", text: /법원경매 사이트/

    # In-app shortcut for users who don't know a 사건번호.
    assert_selector "a[href='#{search_path}']", text: /조건검색/
  end
end
