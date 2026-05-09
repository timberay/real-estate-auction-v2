require "application_system_test_case"

class CaseNumberFirstFlowTest < ApplicationSystemTestCase
  setup do
    visit root_path  # establish guest session
    @user = User.last

    # Give the guest user a property so the select has an option
    @property = Property.create!(case_number: "2026타경99001", court_name: "서울중앙지방법원")
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "PDF upload page requires picking an existing property first" do
    visit new_analysis_path

    assert_text "분석할 물건을 먼저 선택하세요"
    assert_selector "input[type=file][disabled]"
    assert_selector "input[type=submit][disabled]"
  end

  test "after picking property, PDF upload and submit become enabled" do
    visit new_analysis_path

    select "서울중앙지방법원 2026타경99001", from: "분석 대상 물건"

    assert_selector "input[type=file]:not([disabled])"
    assert_selector "input[type=submit]:not([disabled])"
  end
end
