require "application_system_test_case"

class GradeBeginnerGuideTest < ApplicationSystemTestCase
  setup do
    @property = properties(:safe_apartment)
    @user = users(:guest)
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "shows order guide callout and per-section summary when beginner mode is on" do
    @user.update!(beginner_mode: true)
    sign_in_as(@user)
    visit property_inspections_grade_path(@property)

    # Top callout banner.
    assert_text "초심자라면 1·2·3 순서로 보세요"

    # At least one of the per-section beginner summaries should render.
    # The verdict section's summary covers section 1.
    assert_text "이 물건이 안전한지 한 눈에 확인하는 핵심 카드입니다."
  end

  test "hides order guide callout and per-section summaries when beginner mode is off" do
    @user.update!(beginner_mode: false)
    sign_in_as(@user)
    visit property_inspections_grade_path(@property)

    assert_no_text "초심자라면 1·2·3 순서로 보세요"
    assert_no_text "이 물건이 안전한지 한 눈에 확인하는 핵심 카드입니다."
  end
end
