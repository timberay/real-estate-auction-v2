# frozen_string_literal: true

class CompareTableComponent < ViewComponent::Base
  HEADER_CLASSES = "bg-slate-50 dark:bg-slate-800/80"
  HEADER_CELL_CLASSES = "px-4 py-2 text-sm font-medium text-slate-500 dark:text-slate-400"
  CELL_CLASSES = "px-4 py-3 text-sm text-slate-700 dark:text-slate-300"

  def initialize(diff:)
    @diff = diff
  end

  private

  def delta_classes(delta)
    if delta.positive?
      "tabular-nums text-green-600 dark:text-green-400"
    elsif delta.negative?
      "tabular-nums text-red-600 dark:text-red-400"
    else
      "tabular-nums text-slate-500 dark:text-slate-400"
    end
  end

  def formatted_delta(delta)
    if delta.positive?
      "+#{ActiveSupport::NumberHelper.number_to_delimited(delta)}"
    else
      ActiveSupport::NumberHelper.number_to_delimited(delta).to_s
    end
  end
end
