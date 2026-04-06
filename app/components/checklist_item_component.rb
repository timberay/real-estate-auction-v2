# frozen_string_literal: true

class ChecklistItemComponent < ViewComponent::Base
  def initialize(result:, show_resolution: false)
    @result = result
    @checklist_item = result.checklist_item
    @show_resolution = show_resolution
  end

  private

  def auto_source?
    @result.source_type == "auto"
  end

  def manual_source?
    !auto_source?
  end

  def risk_classes
    if manual_source? && @result.has_risk.nil?
      "border-slate-300 bg-slate-50 dark:border-slate-600 dark:bg-slate-800/50"
    elsif @result.has_risk
      if auto_source?
        "border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20"
      else
        "border-yellow-300 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20"
      end
    else
      "border-green-300 bg-green-50 dark:border-green-600 dark:bg-green-900/20"
    end
  end

  def source_badge_classes
    if auto_source?
      if @result.has_risk
        "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300"
      else
        "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300"
      end
    else
      if @result.has_risk.nil?
        "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
      elsif @result.has_risk
        "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300"
      else
        "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300"
      end
    end
  end

  def source_badge_text
    auto_source? ? "AUTO" : "직접 확인"
  end

  def status_text
    if manual_source? && @result.has_risk.nil?
      "미입력"
    elsif @result.has_risk
      auto_source? ? "위험" : "위험 확인"
    else
      "안전"
    end
  end

  def status_color
    if manual_source? && @result.has_risk.nil?
      "text-slate-500 dark:text-slate-400"
    elsif @result.has_risk
      auto_source? ? "text-red-700 dark:text-red-400" : "text-yellow-700 dark:text-yellow-400"
    else
      "text-green-700 dark:text-green-400"
    end
  end

  def show_auto_resolution?
    @show_resolution && auto_source? && @result.has_risk
  end

  def show_manual_input?
    @show_resolution && manual_source?
  end
end
