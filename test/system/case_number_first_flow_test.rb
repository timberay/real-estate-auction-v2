require "application_system_test_case"

class CaseNumberFirstFlowTest < ApplicationSystemTestCase
  setup do
    # Phase A removed lazy guest creation on root_path; protected pages now
    # require an authenticated user. Sign in as a fixture non-guest user.
    @user = users(:budget_user)
    sign_in_as(@user)

    # Give the user a property so the select has an option
    @property = Property.create!(case_number: "2026타경99001", court_name: "서울중앙지방법원")
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "analysis page defaults to manual tab when auto tab is disabled" do
    visit new_analysis_path

    # Manual tab panel is visible (manual analysis form shows)
    assert_text "AI 수동분석이란?"
    # Auto panel is not visible
    assert_no_text "분석할 물건을 먼저 선택하세요"
  end

  test "analysis page shows disclosure panel on load" do
    visit new_analysis_path

    assert_text "외부 LLM API로 전송되는 정보"
    assert_text "프롬프트 복사"
  end
end
