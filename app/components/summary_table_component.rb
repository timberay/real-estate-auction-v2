# frozen_string_literal: true

class SummaryTableComponent < ViewComponent::Base
  CONTAINER_CLASSES = "bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg overflow-hidden"

  def initialize(rows:, title: nil)
    @rows = rows
    @title = title
  end

  private

  def row_classes(row)
    base = "flex justify-between px-4 py-3"
    if row[:highlight]
      "#{base} bg-slate-50 dark:bg-slate-800/50 font-semibold"
    else
      base
    end
  end
end
