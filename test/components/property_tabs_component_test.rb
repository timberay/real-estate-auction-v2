require "test_helper"

class PropertyTabsComponentTest < ViewComponent::TestCase
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
  end

  test "renders all 4 tabs with numbers" do
    render_inline(PropertyTabsComponent.new(property: @property, user: @user, active_tab: :info))
    assert_text "① 기본 정보"
    assert_text "② 체크리스트"
    assert_text "③ 권리 분석"
    assert_text "④ 등급 산정"
  end

  test "highlights active tab" do
    render_inline(PropertyTabsComponent.new(property: @property, user: @user, active_tab: :report))
    assert_selector "[data-active='true']", text: "③ 권리 분석"
  end

  test "shows checkmark for completed checklist tab" do
    UserProperty.find_or_create_by!(user: @user, property: @property).update!(safety_rating: :safe, analyzed_at: Time.current)
    render_inline(PropertyTabsComponent.new(property: @property, user: @user, active_tab: :info))
    assert_selector "[data-tab='checklist'] [data-completed]"
  end
end
