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
end
