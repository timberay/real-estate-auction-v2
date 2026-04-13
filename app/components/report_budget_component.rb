# frozen_string_literal: true

class ReportBudgetComponent < ViewComponent::Base
  include ApplicationHelper

  def initialize(budget_setting:)
    @budget = budget_setting
  end

  def render?
    true
  end

  private

  def fields
    [
      { label: "가용 자금", value: format_price_in_eok(@budget.available_cash) },
      { label: "대출 비율", value: "#{(@budget.loan_ratio * 100).to_i}%" },
      { label: "최대 입찰가", value: format_price_in_eok(@budget.max_bid_amount) },
      { label: "예비비 합계", value: format_price_in_eok(@budget.total_reserves) },
      { label: "선택 지역", value: @budget.region || "—" }
    ]
  end
end
