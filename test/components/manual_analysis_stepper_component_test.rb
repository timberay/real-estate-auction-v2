# frozen_string_literal: true

require "test_helper"

class ManualAnalysisStepperComponentTest < ViewComponent::TestCase
  # --- Step circles ---

  test "renders 4 numbered step circles" do
    render_inline(ManualAnalysisStepperComponent.new)

    assert_selector "[data-step-number]", count: 4
    assert_selector "[data-step-number='1']"
    assert_selector "[data-step-number='2']"
    assert_selector "[data-step-number='3']"
    assert_selector "[data-step-number='4']"
  end

  # --- Step titles ---

  test "renders all 4 step titles" do
    render_inline(ManualAnalysisStepperComponent.new)

    assert_text "프롬프트 복사"
    assert_text "AI에 붙여넣기"
    assert_text "JSON 답변 복사"
    assert_text "결과 업로드"
  end

  # --- Slots ---

  test "step1_action slot renders content inside step 1 card" do
    render_inline(ManualAnalysisStepperComponent.new) do |c|
      c.with_step1_action { "<button>test-copy-button</button>".html_safe }
    end

    step1 = page.find("[data-step='1']")
    assert step1.has_selector?("button", text: "test-copy-button")
  end

  test "step4_action slot renders content inside step 4 card" do
    render_inline(ManualAnalysisStepperComponent.new) do |c|
      c.with_step4_action { "<input type='file' id='test-upload'>".html_safe }
    end

    step4 = page.find("[data-step='4']")
    assert step4.has_selector?("input[type='file']")
  end

  # --- SVG illustrations ---

  test "SVG illustration for step 2 is present and aria-hidden" do
    render_inline(ManualAnalysisStepperComponent.new)

    step2 = page.find("[data-step='2']")
    assert step2.has_selector?("svg[aria-hidden='true']")
  end

  test "SVG illustration for step 3 is present and aria-hidden" do
    render_inline(ManualAnalysisStepperComponent.new)

    step3 = page.find("[data-step='3']")
    assert step3.has_selector?("svg[aria-hidden='true']")
  end

  # --- JSON explainer text ---

  test "JSON explainer text is present so definition is not accidentally removed" do
    render_inline(ManualAnalysisStepperComponent.new)

    assert_text "JSON"
    assert_text "AI가 답해 주는"
  end
end
