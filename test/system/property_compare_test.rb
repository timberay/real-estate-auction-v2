require "application_system_test_case"

class PropertyCompareTest < ApplicationSystemTestCase
  setup do
    @user = users(:budget_user)
    @prop1 = properties(:safe_apartment)
    @prop2 = properties(:risky_villa)
    @prop3 = properties(:unanalyzed_officetel)

    UserProperty.find_or_create_by!(user: @user, property: @prop1)
    UserProperty.find_or_create_by!(user: @user, property: @prop2)
    UserProperty.find_or_create_by!(user: @user, property: @prop3)

    sign_in_as(@user)
  end

  test "checking 2 boxes shows action bar with correct count" do
    visit properties_path

    assert_no_selector "#compare-action-bar:not(.hidden)", wait: 2

    check_property_card(@prop1)
    check_property_card(@prop2)

    within "#compare-action-bar" do
      assert_text "선택한 2건"
      assert_button "비교하기"
    end
  end

  test "비교하기 button navigates to compare page with both properties" do
    visit properties_path

    check_property_card(@prop1)
    check_property_card(@prop2)

    within "#compare-action-bar" do
      click_button "비교하기"
    end

    assert_current_path(/\/properties\/compare/)
    assert_text @prop1.case_number
    assert_text @prop2.case_number
  end

  test "선택 해제 button hides the action bar" do
    visit properties_path

    check_property_card(@prop1)

    within "#compare-action-bar" do
      assert_text "선택한 1건"
      click_button "선택 해제"
    end

    assert_no_selector "#compare-action-bar:not(.hidden)", wait: 2
  end

  # T3.5 #23 — sessionStorage persistence regression guard.
  test "selected checkboxes survive a page refresh via sessionStorage" do
    visit properties_path

    check_property_card(@prop1)
    check_property_card(@prop2)

    within "#compare-action-bar" do
      assert_text "선택한 2건"
    end

    visit properties_path

    within "#compare-action-bar" do
      assert_text "선택한 2건"
      assert_button "비교하기"
    end

    # Verify checkboxes restored, not just the counter
    [ @prop1, @prop2 ].each do |property|
      card = find("##{ActionView::RecordIdentifier.dom_id(property, :card)}")
      within(card) do
        checkbox = find("input[data-property-id='#{property.id}']", visible: :all)
        assert checkbox.checked?,
          "expected property #{property.id} checkbox to remain checked after refresh"
      end
    end
  end

  private

  def check_property_card(property)
    card = find("##{ActionView::RecordIdentifier.dom_id(property, :card)}")
    within(card) do
      checkbox = find("input[data-property-id='#{property.id}']", visible: :all)
      checkbox.click
    end
  end
end
