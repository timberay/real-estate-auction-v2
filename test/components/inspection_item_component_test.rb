require "test_helper"

class InspectionItemComponentTest < ViewComponent::TestCase
  test "renders 자동 badge for auto source" do
    result = inspection_results(:safe_apartment_rights_002)
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "span", text: "자동"
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

  test "highlights selected answer — no when has_risk is true (normal polarity)" do
    result = inspection_results(:manual_risk)
    result.inspection_item.update!(yes_means_safe: true, logic: '{"yes": "safe", "no": "risky"}')
    result.update!(has_risk: true, source_type: "auto")
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

  # --- Inverted polarity (yes_means_safe: false) tests ---

  test "inverted polarity: highlights YES when has_risk is true" do
    result = inspection_results(:risky_villa_rights_003)
    assert_equal true, result.has_risk
    assert_equal false, result.inspection_item.yes_means_safe
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-logic-selected='yes']"
    refute_selector "[data-logic-selected='no']"
  end

  test "inverted polarity: highlights NO when has_risk is false" do
    result = inspection_results(:safe_apartment_rights_003)
    assert_equal false, result.has_risk
    assert_equal false, result.inspection_item.yes_means_safe
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-logic-selected='no']"
    refute_selector "[data-logic-selected='yes']"
  end

  test "inverted polarity: YES row uses red (danger) classes when selected" do
    result = inspection_results(:risky_villa_rights_003)
    render_inline(InspectionItemComponent.new(result: result))

    yes_row = page.find("[data-inspection-item-target='logicYes']")
    assert_includes yes_row[:class], "bg-red-100"
    assert_includes yes_row[:class], "text-red-800"
  end

  test "inverted polarity: NO row uses green (safe) classes when selected" do
    result = inspection_results(:safe_apartment_rights_003)
    render_inline(InspectionItemComponent.new(result: result))

    no_row = page.find("[data-inspection-item-target='logicNo']")
    assert_includes no_row[:class], "bg-green-100"
    assert_includes no_row[:class], "text-green-800"
  end

  test "normal polarity: YES row uses green (safe) classes when selected" do
    result = inspection_results(:safe_apartment_rights_002)
    assert_equal true, result.inspection_item.yes_means_safe
    render_inline(InspectionItemComponent.new(result: result))

    yes_row = page.find("[data-inspection-item-target='logicYes']")
    assert_includes yes_row[:class], "bg-green-100"
    assert_includes yes_row[:class], "text-green-800"
  end

  # --- Evidence block tests ---

  test "renders evidence block with field data for auto result" do
    result = inspection_results(:safe_apartment_rights_002)
    result.update!(evidence: {
      "source_label" => "법원경매 물건정보",
      "fields" => [ { "label" => "물건종류", "value" => "아파트" } ]
    })
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-evidence]"
    assert_text "판정 근거"
    assert_text "법원경매 물건정보"
    assert_text "물건종류"
    assert_text "아파트"
  end

  test "renders evidence block with keyword data for auto result" do
    result = inspection_results(:safe_apartment_rights_003)
    result.update!(evidence: {
      "source_label" => "비고, 물건명세서, 현황조사서",
      "keywords" => { "searched" => [ "유치권", "법정지상권" ], "found" => false }
    })
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-evidence]"
    assert_text "판정 근거"
    assert_text "비고, 물건명세서, 현황조사서"
    assert_text "유치권"
    assert_text "해당 없음"
  end

  test "does not render evidence block for manual result" do
    result = inspection_results(:manual_risk)
    render_inline(InspectionItemComponent.new(result: result))

    refute_selector "[data-evidence]"
  end

  test "renders AI 분석 badge for ai source" do
    result = inspection_results(:risky_villa_rights_003)
    result.update!(
      source_type: :ai, has_risk: true,
      evidence: { "source_label" => "AI 분석", "confidence" => "high", "reasoning" => "테스트 근거" }
    )
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "span", text: "AI 분석"
  end

  test "renders evidence block for ai result with reasoning" do
    result = inspection_results(:risky_villa_rights_003)
    result.update!(
      source_type: :ai, has_risk: true,
      evidence: { "source_label" => "AI 분석", "confidence" => "high", "reasoning" => "유치권 신고가 있습니다." }
    )
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-evidence]"
    assert_text "유치권 신고가 있습니다."
  end

  test "renders keyword found state with 발견 text" do
    result = inspection_results(:risky_villa_rights_003)
    result.update!(evidence: {
      "source_label" => "비고, 물건명세서, 현황조사서",
      "keywords" => { "searched" => [ "유치권", "법정지상권" ], "found" => true }
    })
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-evidence]"
    assert_text "발견"
  end

  test "renders reasoning with line breaks preserved" do
    result = inspection_results(:risky_villa_rights_003)
    result.update!(
      source_type: :ai, has_risk: true,
      evidence: { "source_label" => "AI 분석", "confidence" => "high", "reasoning" => "첫째 줄입니다.\n둘째 줄입니다." }
    )
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-evidence] span.whitespace-pre-line", text: /첫째 줄입니다/
  end

  # --- Resolvable-aware status (matches tab-level rating) ---

  test "has_risk=true + resolvable=true renders 주의 label with yellow box" do
    result = inspection_results(:risky_villa_rights_003)
    result.update!(source_type: :ai, has_risk: true, resolvable: true)
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-inspection-item-target='statusLabel']", text: "주의"
    box = page.find("[data-controller='inspection-item']")
    assert_includes box[:class], "bg-yellow-100"
    assert_includes box[:class], "border-yellow-400"
  end

  test "has_risk=true + resolvable=false renders 경고 label with red box" do
    result = inspection_results(:risky_villa_rights_003)
    result.update!(source_type: :ai, has_risk: true, resolvable: false)
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-inspection-item-target='statusLabel']", text: "경고"
    box = page.find("[data-controller='inspection-item']")
    assert_includes box[:class], "bg-red-100"
    assert_includes box[:class], "border-red-400"
  end

  test "has_risk=true + resolvable=nil (AI source) keeps 위험 label with red box" do
    result = inspection_results(:risky_villa_rights_003)
    result.update!(source_type: :ai, has_risk: true, resolvable: nil)
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-inspection-item-target='statusLabel']", text: "위험"
    box = page.find("[data-controller='inspection-item']")
    assert_includes box[:class], "bg-red-100"
    assert_includes box[:class], "border-red-400"
  end

  test "has_risk=true + resolvable=true (manual source) renders 주의 label with yellow box" do
    result = inspection_results(:manual_risk)
    assert_equal true, result.has_risk
    assert_equal true, result.resolvable
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-inspection-item-target='statusLabel']", text: "주의"
    box = page.find("[data-controller='inspection-item']")
    assert_includes box[:class], "bg-yellow-100"
  end

  test "renders evidence block for ai result with none confidence (참고)" do
    result = inspection_results(:risky_villa_rights_003)
    result.update!(
      source_type: :ai, has_risk: nil,
      evidence: { "source_label" => "AI 분석 (참고)", "confidence" => "none", "reasoning" => "해당 물건은 단독주택이므로 직접 확인이 필요합니다." }
    )
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "[data-evidence]"
    assert_text "AI 분석 (참고)"
    assert_text "해당 물건은 단독주택이므로 직접 확인이 필요합니다."
  end

  test "renders item code as a monospace badge" do
    result = inspection_results(:safe_apartment_rights_002)
    render_inline(InspectionItemComponent.new(result: result))

    assert_selector "span.font-mono", text: result.inspection_item.code
  end
end
