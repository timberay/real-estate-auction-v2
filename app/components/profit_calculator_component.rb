# frozen_string_literal: true

class ProfitCalculatorComponent < ViewComponent::Base
  def initialize(property:, budget_setting:, report:, show_title: true)
    @property = property
    @budget = budget_setting
    @report = report
    @show_title = show_title
  end

  # All values normalized to 만원 for the Stimulus controller
  def min_bid_manwon
    @property.min_bid_price.to_i / 10000
  end

  def appraisal_manwon
    @property.appraisal_price.to_i / 10000
  end

  def assumed_amount
    @report&.assumed_amount.to_i / 10000
  end

  def scrivener_fee
    @budget&.scrivener_fee.to_i
  end

  def repair_cost
    @budget&.repair_cost.to_i
  end

  def moving_cost
    @budget&.moving_cost.to_i
  end

  def maintenance_fee
    @budget&.maintenance_fee.to_i
  end
end
