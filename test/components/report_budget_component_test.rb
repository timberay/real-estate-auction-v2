# frozen_string_literal: true

require "test_helper"

class ReportBudgetComponentTest < ViewComponent::TestCase
  test "renders available cash" do
    budget = budget_settings(:completed)
    render_inline(ReportBudgetComponent.new(budget_setting: budget))
    assert_text "3억"
  end

  test "renders loan ratio as percentage" do
    budget = budget_settings(:completed)
    render_inline(ReportBudgetComponent.new(budget_setting: budget))
    assert_text "70%"
  end

  test "renders max bid amount formatted" do
    budget = budget_settings(:completed)
    render_inline(ReportBudgetComponent.new(budget_setting: budget))
    assert_text "9억 6,200만원"
  end

  test "renders total reserves" do
    budget = budget_settings(:completed)
    render_inline(ReportBudgetComponent.new(budget_setting: budget))
    assert_text "1,140만원"
  end

  test "renders prompt when budget is nil" do
    render_inline(ReportBudgetComponent.new(budget_setting: nil))
    assert_text "예산 설정을 먼저 완료해주세요"
  end
end
