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
      "border-slate-400 bg-slate-100 dark:border-slate-600 dark:bg-slate-800/50"
    elsif @result.has_risk
      auto_source? ? "border-red-400 bg-red-100 dark:border-red-600 dark:bg-red-900/20" : "border-yellow-400 bg-yellow-100 dark:border-yellow-600 dark:bg-yellow-900/20"
    else
      "border-green-400 bg-green-100 dark:border-green-600 dark:bg-green-900/20"
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
      "bg-slate-200 text-slate-600 dark:bg-slate-700 dark:text-slate-400"
    elsif overridden?
      "bg-amber-100 text-amber-700 ring-1 ring-inset ring-amber-600/20 dark:bg-amber-900/30 dark:text-amber-300 dark:ring-amber-400/20"
    else
      "bg-amber-100 text-amber-700 ring-1 ring-inset ring-amber-600/20 dark:bg-amber-900/30 dark:text-amber-300 dark:ring-amber-400/20"
    end
  end

  def status_text
    if manual_source? && @result.has_risk.nil? then "미입력"
    elsif @result.has_risk then auto_source? ? "위험" : "위험 확인"
    else "안전"
    end
  end

  def status_classes
    if manual_source? && @result.has_risk.nil?
      "text-slate-400 dark:text-slate-500"
    elsif @result.has_risk
      "text-red-600 dark:text-red-400"
    else
      "text-green-600 dark:text-green-400"
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
      answer_means_safe ? "bg-green-100 dark:bg-green-900/20 font-semibold text-green-800 dark:text-green-300" : "bg-red-100 dark:bg-red-900/20 font-semibold text-red-800 dark:text-red-300"
    else
      "text-slate-400 dark:text-slate-500"
    end
  end

  def logic_no_classes
    return "" unless selected_answer
    if selected_answer == "no"
      answer_means_safe = !@item.yes_means_safe?
      answer_means_safe ? "bg-green-100 dark:bg-green-900/20 font-semibold text-green-800 dark:text-green-300" : "bg-red-100 dark:bg-red-900/20 font-semibold text-red-800 dark:text-red-300"
    else
      "text-slate-400 dark:text-slate-500"
    end
  end
end
