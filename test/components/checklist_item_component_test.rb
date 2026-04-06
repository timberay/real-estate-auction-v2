# frozen_string_literal: true

require "test_helper"

class ChecklistItemComponentTest < ViewComponent::TestCase
  test "auto safe: renders green card with no input" do
    result = property_check_results(:safe_apartment_rights_011)
    render_inline(ChecklistItemComponent.new(result: result, show_resolution: true))
    assert_text "안전"
    assert_selector "[data-source-badge]", text: "AUTO"
    assert_no_selector "input[type='radio']"
  end

  test "auto risk: renders red card with resolution input" do
    result = property_check_results(:risky_villa_rights_011)
    render_inline(ChecklistItemComponent.new(result: result, show_resolution: true))
    assert_text "위험"
    assert_selector "[data-source-badge]", text: "AUTO"
    assert_selector "input[type='radio'][value='true']"  # resolvable=true
    assert_selector "input[type='radio'][value='false']"  # resolvable=false
  end

  test "manual unanswered: renders gray card with yes/no input" do
    result = property_check_results(:manual_unanswered_apartment_manual_001)
    render_inline(ChecklistItemComponent.new(result: result, show_resolution: true))
    assert_text "미입력"
    assert_selector "[data-source-badge]", text: "직접 확인"
    assert_selector "input[type='radio'][value='true']"  # has_risk=true (예)
    assert_selector "input[type='radio'][value='false']"  # has_risk=false (아니오)
  end

  test "manual risk confirmed: renders yellow card with resolution sub-section" do
    result = property_check_results(:manual_risk_villa_manual_001)
    render_inline(ChecklistItemComponent.new(result: result, show_resolution: true))
    assert_text "위험 확인"
    assert_selector "[data-resolution-section]"
  end

  test "show_resolution false: no input rendered for any type" do
    result = property_check_results(:risky_villa_rights_011)
    render_inline(ChecklistItemComponent.new(result: result, show_resolution: false))
    assert_text "위험"
    assert_no_selector "input[type='radio']"
  end
end
