# frozen_string_literal: true

class ChecklistItemComponent < ViewComponent::Base
  def initialize(result:, show_resolution: false)
    @result = result
    @checklist_item = result.checklist_item
    @show_resolution = show_resolution
  end

  private

  def risk_classes
    if @result.has_risk
      if @result.resolvable == true
        "border-yellow-300 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20"
      else
        "border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20"
      end
    else
      "border-green-300 bg-green-50 dark:border-green-600 dark:bg-green-900/20"
    end
  end

  def status_text
    @result.has_risk ? "위험" : "안전"
  end

  def status_color
    @result.has_risk ? "text-red-700 dark:text-red-400" : "text-green-700 dark:text-green-400"
  end
end
