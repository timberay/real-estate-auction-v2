# frozen_string_literal: true

require "test_helper"

class ChecklistItemComponentTest < ViewComponent::TestCase
  test "renders question text" do
    result = property_check_results(:safe_apartment_rights_011)
    render_inline(ChecklistItemComponent.new(result: result))
    assert_text result.checklist_item.question
  end

  test "shows safe status for no-risk result" do
    result = property_check_results(:safe_apartment_rights_011)
    render_inline(ChecklistItemComponent.new(result: result))
    assert_text "안전"
  end

  test "shows risk status for risky result" do
    result = property_check_results(:risky_villa_rights_011)
    render_inline(ChecklistItemComponent.new(result: result))
    assert_text "위험"
  end
end
