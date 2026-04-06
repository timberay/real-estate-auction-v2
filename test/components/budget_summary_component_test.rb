# frozen_string_literal: true

require "test_helper"

class BudgetSummaryComponentTest < ViewComponent::TestCase
  # --- Calculated state ---

  test "renders calculated state when max_bid_amount is present" do
    setting = budget_settings(:completed)

    render_inline(BudgetSummaryComponent.new(setting: setting))

    assert_selector "div[class*='bg-blue-50']"
    assert_selector "div[class*='border-blue-200']"
    assert_no_selector "div[class*='border-dashed']"
    assert_text "최대입찰가"
    assert_text "96,200만원"
  end

  test "renders all four metrics with calculated values" do
    setting = budget_settings(:completed)

    render_inline(BudgetSummaryComponent.new(setting: setting))

    assert_text "유용자금"
    assert_text "30,000만원"
    assert_text "예비비 합계"
    assert_text "1,140만원"
    assert_text "대출비율"
    assert_text "70%"
  end

  # --- Uncalculated state ---

  test "renders uncalculated state when setting is nil" do
    render_inline(BudgetSummaryComponent.new(setting: nil))

    assert_selector "div[class*='bg-slate-50']"
    assert_selector "div[class*='border-dashed']"
    assert_text "최대입찰가"
    assert_selector "p", text: "—", minimum: 4
  end

  test "renders uncalculated state when max_bid_amount is nil" do
    setting = BudgetSetting.new

    render_inline(BudgetSummaryComponent.new(setting: setting))

    assert_selector "div[class*='border-dashed']"
  end

  # --- Responsive grid ---

  test "renders responsive grid classes" do
    render_inline(BudgetSummaryComponent.new(setting: nil))

    assert_selector "div[class*='grid-cols-2']"
    assert_selector "div[class*='sm:grid-cols-4']"
  end
end
