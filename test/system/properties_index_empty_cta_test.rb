require "application_system_test_case"

# B19 / UX-audit B-9: empty state on /properties (no user_properties) should
# offer a CTA that takes the user to /search (물건 목록) so they aren't dead-ended.
class PropertiesIndexEmptyCtaTest < ApplicationSystemTestCase
  setup do
    @user = users(:budget_user) # has no user_properties
    sign_in_as(@user)
  end

  test "empty state shows CTA linking to 조건검색 (search_path)" do
    visit properties_path

    within "#user-properties-empty-state" do
      assert_selector "a[href='#{search_path}']", text: "물건 목록에서 검색하기"
    end
  end
end
