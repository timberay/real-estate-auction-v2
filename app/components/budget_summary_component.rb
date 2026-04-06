# frozen_string_literal: true

class BudgetSummaryComponent < ViewComponent::Base
  include ActionView::Helpers::NumberHelper

  def initialize(setting: nil)
    @setting = setting
  end

  private

  def calculated?
    @setting.present? && @setting.max_bid_amount.present?
  end

  def container_classes
    base = "grid grid-cols-2 sm:grid-cols-4 gap-3 rounded-lg p-4 mb-6 text-center"
    if calculated?
      "#{base} bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800"
    else
      "#{base} bg-slate-50 dark:bg-slate-800 border border-dashed border-slate-300 dark:border-slate-600"
    end
  end

  def max_bid_amount
    calculated? ? helpers.format_price_in_eok(@setting.max_bid_amount) : "—"
  end

  def available_cash
    calculated? ? helpers.format_price_in_eok(@setting.available_cash) : "—"
  end

  def total_reserves
    calculated? ? helpers.format_price_in_eok(@setting.total_reserves) : "—"
  end

  def loan_ratio
    calculated? ? "#{(@setting.loan_ratio * 100).round}%" : "—"
  end

  def primary_value_classes
    if calculated?
      "text-base font-bold tabular-nums text-blue-700 dark:text-blue-300"
    else
      "text-base font-bold tabular-nums text-slate-300 dark:text-slate-600"
    end
  end

  def secondary_value_classes
    if calculated?
      "text-sm font-semibold tabular-nums text-slate-700 dark:text-slate-200"
    else
      "text-sm font-semibold tabular-nums text-slate-300 dark:text-slate-600"
    end
  end

  def label_classes
    if calculated?
      "text-xs text-slate-500 dark:text-slate-400"
    else
      "text-xs text-slate-400 dark:text-slate-500"
    end
  end
end
