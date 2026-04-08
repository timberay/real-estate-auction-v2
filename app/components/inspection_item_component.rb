class InspectionItemComponent < ViewComponent::Base
  def initialize(result:, show_resolution: false)
    @result = result
    @item = result.inspection_item
    @show_resolution = show_resolution
  end

  private

  def auto_source? = @result.source_type == "auto"
  def manual_source? = !auto_source?
  def overridden? = manual_source? && @result.auto_value.present?

  def risk_classes
    if manual_source? && @result.has_risk.nil?
      "border-slate-300 bg-slate-50 dark:border-slate-600 dark:bg-slate-800/50"
    elsif @result.has_risk
      auto_source? ? "border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20" : "border-yellow-300 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20"
    else
      "border-green-300 bg-green-50 dark:border-green-600 dark:bg-green-900/20"
    end
  end

  def source_badge_text
    if auto_source?
      "자동"
    elsif overridden?
      "수정됨"
    else
      "직접 확인"
    end
  end

  def source_badge_classes
    if auto_source?
      "bg-blue-100 text-blue-700 dark:bg-blue-900/30 dark:text-blue-300"
    elsif overridden?
      "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"
    else
      "bg-slate-100 text-slate-600 dark:bg-slate-700 dark:text-slate-300"
    end
  end

  def status_text
    if manual_source? && @result.has_risk.nil? then "미입력"
    elsif @result.has_risk then auto_source? ? "위험" : "위험 확인"
    else "안전"
    end
  end

  def show_auto_resolution? = @show_resolution && auto_source? && @result.has_risk
  def show_manual_input? = @show_resolution && manual_source? && !overridden?
  def show_edit_mode? = @show_resolution && (auto_source? || overridden?)

  def yes_radio_value
    @item.yes_means_safe? ? "false" : "true"
  end

  def no_radio_value
    @item.yes_means_safe? ? "true" : "false"
  end

  def logic_present? = @item.logic.present? && @item.logic["yes"].present?

  def selected_answer
    return nil if @result.has_risk.nil?
    if @item.yes_means_safe?
      @result.has_risk ? "no" : "yes"
    else
      @result.has_risk ? "yes" : "no"
    end
  end

  def logic_yes_classes
    return "" unless selected_answer
    if selected_answer == "yes"
      answer_means_safe = @item.yes_means_safe?
      answer_means_safe ? "bg-green-50 dark:bg-green-900/20 font-semibold text-green-800 dark:text-green-300" : "bg-red-50 dark:bg-red-900/20 font-semibold text-red-800 dark:text-red-300"
    else
      "text-slate-400 dark:text-slate-500"
    end
  end

  def logic_no_classes
    return "" unless selected_answer
    if selected_answer == "no"
      answer_means_safe = !@item.yes_means_safe?
      answer_means_safe ? "bg-green-50 dark:bg-green-900/20 font-semibold text-green-800 dark:text-green-300" : "bg-red-50 dark:bg-red-900/20 font-semibold text-red-800 dark:text-red-300"
    else
      "text-slate-400 dark:text-slate-500"
    end
  end
end
