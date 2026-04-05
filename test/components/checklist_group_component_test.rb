# frozen_string_literal: true

require "test_helper"

class ChecklistGroupComponentTest < ViewComponent::TestCase
  test "renders axis label" do
    results = [ property_check_results(:safe_apartment_rights_011) ]
    render_inline(ChecklistGroupComponent.new(axis: "legal", results: results))
    assert_text "법적 위험"
  end

  test "renders checklist items" do
    results = [ property_check_results(:safe_apartment_rights_011) ]
    render_inline(ChecklistGroupComponent.new(axis: "legal", results: results))
    assert_text results.first.checklist_item.question
  end
end
