require "test_helper"

class InspectionItemComponentTest < ViewComponent::TestCase
  test "renders AUTO badge for auto source" do
    result = inspection_results(:safe_apartment_rights_002)
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "span", text: "AUTO"
  end

  test "renders 직접 확인 badge for manual source without auto_value" do
    result = inspection_results(:manual_risk)
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "span", text: "직접 확인"
  end

  test "renders 수정됨 badge for manual source with auto_value" do
    result = inspection_results(:safe_apartment_rights_002)
    result.update!(source_type: "manual", auto_value: "false")
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "span", text: "수정됨"
  end

  test "renders logic yes/no explanations when logic present" do
    result = inspection_results(:safe_apartment_rights_002)
    render_inline(InspectionItemComponent.new(result: result))

    logic = result.inspection_item.logic
    assert_text logic["yes"]
    assert_text logic["no"]
  end

  test "highlights selected answer — yes when has_risk is false" do
    result = inspection_results(:safe_apartment_rights_002)
    assert_equal false, result.has_risk
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-logic-selected='yes']"
    refute_selector "[data-logic-selected='no']"
  end

  test "highlights selected answer — no when has_risk is true" do
    result = inspection_results(:risky_villa_rights_011)
    assert_equal true, result.has_risk
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-logic-selected='no']"
    refute_selector "[data-logic-selected='yes']"
  end

  test "no highlight when has_risk is nil" do
    result = inspection_results(:manual_unanswered)
    render_inline(InspectionItemComponent.new(result: result))

    refute_selector "[data-logic-selected]"
  end

  test "omits logic section when logic is blank" do
    result = inspection_results(:safe_apartment_rights_002)
    result.inspection_item.update!(logic: nil)
    render_inline(InspectionItemComponent.new(result: result))

    refute_selector "[data-logic-section]"
  end
end
