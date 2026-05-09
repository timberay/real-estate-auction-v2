require "application_system_test_case"

class ChecklistGlossaryTest < ApplicationSystemTestCase
  setup do
    @property = properties(:safe_apartment)
    @user = users(:guest)
    # Ensure user owns the property
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "checklist question shows glossary annotation when beginner mode is on" do
    @user.update!(beginner_mode: true)
    visit root_path
    sign_in_as(@user)
    visit edit_property_inspections_tab_path(@property, tab_key: "rights_analysis")

    # rights_002 question contains 매각물건명세서, 가등기, 가처분
    assert_selector "[data-controller='glossary']", minimum: 1
  end

  test "glossary annotation is absent when beginner mode is off" do
    @user.update!(beginner_mode: false)
    visit root_path
    sign_in_as(@user)
    visit edit_property_inspections_tab_path(@property, tab_key: "rights_analysis")

    assert_no_selector "[data-controller='glossary']"
  end

  test "toggle_beginner_mode button is visible on inspection page" do
    @user.update!(beginner_mode: true)
    visit root_path
    sign_in_as(@user)
    visit edit_property_inspections_tab_path(@property, tab_key: "rights_analysis")

    assert_selector "button", text: "초심자 모드 ✓"
  end

  test "clicking toggle_beginner_mode flips the preference" do
    @user.update!(beginner_mode: true)
    visit root_path
    sign_in_as(@user)
    visit edit_property_inspections_tab_path(@property, tab_key: "rights_analysis")

    find("button", text: "초심자 모드 ✓").click
    assert_equal false, @user.reload.beginner_mode
  end
end
