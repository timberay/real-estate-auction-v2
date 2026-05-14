# frozen_string_literal: true

require "test_helper"

class ProfitCalculatorComponentTest < ViewComponent::TestCase
  setup do
    @property = properties(:safe_apartment)
    @budget = budget_settings(:completed)
    @report = rights_analysis_reports(:safe_apartment_report)
  end

  test "renders with all data and correct data attributes" do
    render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    # Property values converted from 원 to 만원
    assert_selector "[data-profit-calculator-min-bid-value='56000']"
    assert_selector "[data-profit-calculator-appraisal-value='80000']"
    # Report assumed_amount converted from 원 to 만원
    assert_selector "[data-profit-calculator-assumed-amount-value='0']"
    # Budget reserves already in 만원
    assert_selector "[data-profit-calculator-scrivener-fee-value='80']"
    assert_selector "[data-profit-calculator-repair-cost-value='500']"
    assert_selector "[data-profit-calculator-moving-cost-value='150']"
    assert_selector "[data-profit-calculator-maintenance-fee-value='50']"
  end

  test "renders disclaimer badge" do
    render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    assert_text "추정치"
    assert_text "세무사 상담을 권장합니다"
  end

  test "renders with nil budget_setting using zero defaults" do
    render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: nil,
      report: @report
    ))

    assert_selector "[data-profit-calculator-scrivener-fee-value='0']"
    assert_selector "[data-profit-calculator-repair-cost-value='0']"
    assert_selector "[data-profit-calculator-moving-cost-value='0']"
    assert_selector "[data-profit-calculator-maintenance-fee-value='0']"
  end

  test "renders with nil report using zero assumed_amount" do
    render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: nil
    ))

    assert_selector "[data-profit-calculator-assumed-amount-value='0']"
  end

  test "hides title when show_title: false" do
    render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report,
      show_title: false
    ))

    assert_no_text "순수익 계산기"
    assert_text "추정치"
  end

  test "converts assumed_amount from 원 to 만원" do
    # risky_villa_report.assumed_amount is 30_000_000 (원) → 3,000 (만원)
    render_inline(ProfitCalculatorComponent.new(
      property: properties(:risky_villa),
      budget_setting: @budget,
      report: rights_analysis_reports(:risky_villa_report)
    ))

    assert_selector "[data-profit-calculator-assumed-amount-value='3000']"
  end

  # B25 / audit B-19 — tax terms must carry a tooltip explaining their effect
  # on 양도세 (capital-gains tax) so beginners know why the row is annotated.
  test "renders tooltip for 경비 불산입 explaining it is excluded from CGT base" do
    render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    assert_selector "[data-controller='tooltip'][data-tooltip-content-value='양도세 계산 시 차감 불가 (지출했지만 공제 안 됨)']"
  end

  test "renders tooltip for 필요경비만 공제 explaining only deductible costs reduce CGT" do
    render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    assert_selector "[data-controller='tooltip'][data-tooltip-content-value='수선비·취득세 등은 양도세 계산 시 차감 가능']"
  end

  test "renders compact legal disclaimer about user responsibility (B28)" do
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    )).to_s

    assert_match(/투자 결정의 (최종 )?책임은 사용자에게/, rendered)
  end

  # F-B — wire AcquisitionTaxCalculator brackets into the Stimulus controller
  # so the slider drives per-bracket tax rates instead of a hardcoded
  # effective-rate constant.
  test "exposes 4-tier acquisition tax brackets via data attribute" do
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,        # safe_apartment: exclusive_area=84.5 → area_over_85=false
      budget_setting: @budget,    # apartment, default region=제주 (non-regulated)
      report: @report
    ))

    root = rendered.css("[data-controller='profit-calculator']").first
    raw = root["data-profit-calculator-tax-brackets-value"]
    refute_nil raw, "expected tax brackets data attribute to be present"

    brackets = JSON.parse(raw)
    assert_equal %w[homeless multi_home_2 multi_home_3plus single_home],
                 brackets.keys.sort

    # 84.5㎡ apartment in non-regulated region → homeless tier has 3 brackets
    homeless = brackets["homeless"]
    assert_equal 3, homeless.length
    assert_in_delta 0.0110, homeless[0]["rate"].to_f, 1e-6
    assert_equal 60000, homeless[0]["max"]
    assert_in_delta 0.0220, homeless[1]["rate"].to_f, 1e-6
    assert_equal 90000, homeless[1]["max"]
    assert_in_delta 0.0330, homeless[2]["rate"].to_f, 1e-6
    assert_nil homeless[2]["max"]

    # multi_home_3plus non-regulated → single open-ended 8.4% bracket
    multi3 = brackets["multi_home_3plus"]
    assert_equal 1, multi3.length
    assert_in_delta 0.0840, multi3[0]["rate"].to_f, 1e-6
    assert_nil multi3[0]["max"]
  end

  test "renders empty acquisition tax brackets when budget_setting is nil" do
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: nil,
      report: @report
    ))

    root = rendered.css("[data-controller='profit-calculator']").first
    brackets = JSON.parse(root["data-profit-calculator-tax-brackets-value"])
    assert_empty brackets,
                 "without a budget setting we have no property_type_id to look up brackets"
  end

  # F-B — radio values must match the AcquisitionTaxRate HOUSEHOLD_TIERS keys
  # so the JS can use the selected value directly as a brackets lookup key.
  test "renders 4-tier ownership radio aligned with AcquisitionTaxRate tiers" do
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    values = rendered.css("input[type='radio'][name='ownership']").map { |i| i["value"] }
    assert_equal %w[homeless single_home multi_home_2 multi_home_3plus], values
  end

  test "pre-selects ownership radio matching budget_setting.household_tier" do
    @budget.update!(household_tier: "multi_home_2")
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    checked = rendered.css("input[type='radio'][name='ownership'][checked]").first
    refute_nil checked, "expected exactly one ownership radio to be pre-checked"
    assert_equal "multi_home_2", checked["value"]
  end

  test "defaults ownership radio to homeless when budget_setting is nil" do
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: nil,
      report: @report
    ))

    checked = rendered.css("input[type='radio'][name='ownership'][checked]").first
    refute_nil checked
    assert_equal "homeless", checked["value"]
  end

  # F-C-1 — propagate the precise-mode opt-in so the JS bracket lookup can
  # switch to the progressive formula in the 6~9억 bracket.
  test "exposes precise_mode=true when budget_setting opts in" do
    @budget.update!(acquisition_tax_precise_mode: true)
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    root = rendered.css("[data-controller='profit-calculator']").first
    assert_equal "true", root["data-profit-calculator-precise-mode-value"]
  end

  test "exposes precise_mode=false by default" do
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    root = rendered.css("[data-controller='profit-calculator']").first
    assert_equal "false", root["data-profit-calculator-precise-mode-value"]
  end

  test "exposes precise_mode=false when budget_setting is nil" do
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: nil,
      report: @report
    ))

    root = rendered.css("[data-controller='profit-calculator']").first
    assert_equal "false", root["data-profit-calculator-precise-mode-value"]
  end

  # T1.2 — wire TransferTaxCalculator matrix into the Stimulus controller so
  # the CGT row reflects the seeded effective-rate table instead of a 12-cell
  # hardcoded constant. Mirrors the F-B acquisition-tax-brackets pattern.
  test "exposes 4-tier × 3-period transfer tax matrix via data attribute" do
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    root = rendered.css("[data-controller='profit-calculator']").first
    raw = root["data-profit-calculator-cgt-matrix-value"]
    refute_nil raw, "expected cgt matrix data attribute to be present"

    matrix = JSON.parse(raw)
    assert_equal %w[homeless multi_home_2 multi_home_3plus single_home], matrix.keys.sort
    %w[under_1y btw_1_2y over_2y].each do |period|
      assert_in_delta 0.70, matrix["homeless"]["under_1y"].to_f, 1e-6 if period == "under_1y"
      assert matrix["homeless"].key?(period), "homeless missing period #{period}"
    end

    # Default budget region is 제주 (non-regulated) → multi_home_2 over_2y = 0.24
    assert_in_delta 0.24, matrix["multi_home_2"]["over_2y"].to_f, 1e-6
    # 1세대1주택 비과세 가정
    assert_in_delta 0.0, matrix["single_home"]["over_2y"].to_f, 1e-6
  end

  test "transfer tax matrix differentiates regulated region for multi_home over_2y" do
    @budget.update!(region: "서울특별시") # regulated
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    matrix = JSON.parse(
      rendered.css("[data-controller='profit-calculator']").first["data-profit-calculator-cgt-matrix-value"]
    )
    assert_in_delta 0.44, matrix["multi_home_2"]["over_2y"].to_f, 1e-6
    assert_in_delta 0.54, matrix["multi_home_3plus"]["over_2y"].to_f, 1e-6
  end

  test "transfer tax matrix is empty hash when budget_setting is nil" do
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: nil,
      report: @report
    ))

    matrix = JSON.parse(
      rendered.css("[data-controller='profit-calculator']").first["data-profit-calculator-cgt-matrix-value"]
    )
    assert_empty matrix
  end

  # Holding-period radio values must match TransferTaxRate::HOLDING_PERIODS so
  # the JS can use the selected value as a matrix lookup key directly.
  test "renders 3-period holding radio aligned with TransferTaxRate periods" do
    rendered = render_inline(ProfitCalculatorComponent.new(
      property: @property,
      budget_setting: @budget,
      report: @report
    ))

    values = rendered.css("input[type='radio'][name='holding_period']").map { |i| i["value"] }
    assert_equal %w[under_1y btw_1_2y over_2y], values
  end
end
