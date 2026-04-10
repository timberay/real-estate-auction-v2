class InspectionItemComponent < ViewComponent::Base
  def initialize(result:, show_resolution: false)
    @result = result
    @item = result.inspection_item
    @show_resolution = show_resolution
  end

  private

  def auto_or_ai_source? = @result.source_type.in?(%w[auto ai])
  def ai_source? = @result.source_type == "ai"
  def auto_source? = @result.source_type == "auto"
  def manual_source? = @result.source_type == "manual"
  def overridden? = manual_source? && @result.auto_value.present?

  def risk_classes
    if !auto_or_ai_source? && @result.has_risk.nil?
      "border-slate-400 bg-slate-100 dark:border-slate-600 dark:bg-slate-800/50"
    elsif @result.has_risk
      auto_or_ai_source? ? "border-red-400 bg-red-100 dark:border-red-600 dark:bg-red-900/20" : "border-yellow-400 bg-yellow-100 dark:border-yellow-600 dark:bg-yellow-900/20"
    else
      "border-green-400 bg-green-100 dark:border-green-600 dark:bg-green-900/20"
    end
  end

  def source_badge_text
    if ai_source?
      "AI 분석"
    elsif auto_source?
      "자동"
    elsif overridden?
      "수정됨"
    else
      "직접 확인"
    end
  end

  def source_badge_classes
    if ai_source?
      "bg-blue-100 text-blue-700 ring-1 ring-inset ring-blue-600/20 dark:bg-blue-900/30 dark:text-blue-300 dark:ring-blue-400/20"
    elsif auto_source?
      "bg-slate-200 text-slate-600 dark:bg-slate-700 dark:text-slate-400"
    elsif overridden?
      "bg-amber-100 text-amber-700 ring-1 ring-inset ring-amber-600/20 dark:bg-amber-900/30 dark:text-amber-300 dark:ring-amber-400/20"
    else
      "bg-amber-100 text-amber-700 ring-1 ring-inset ring-amber-600/20 dark:bg-amber-900/30 dark:text-amber-300 dark:ring-amber-400/20"
    end
  end

  def status_text
    if !auto_or_ai_source? && @result.has_risk.nil? then "미입력"
    elsif @result.has_risk then auto_or_ai_source? ? "위험" : "위험 확인"
    else "안전"
    end
  end

  def status_classes
    if !auto_or_ai_source? && @result.has_risk.nil?
      "text-slate-400 dark:text-slate-500"
    elsif @result.has_risk
      "text-red-600 dark:text-red-400"
    else
      "text-green-600 dark:text-green-400"
    end
  end

  def show_auto_resolution? = @show_resolution && auto_or_ai_source? && @result.has_risk
  def show_manual_input? = @show_resolution && !auto_or_ai_source? && !overridden?
  def show_edit_mode? = @show_resolution && (auto_or_ai_source? || overridden?)

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
    return "text-slate-500 dark:text-slate-400" unless selected_answer
    if selected_answer == "yes"
      answer_means_safe = @item.yes_means_safe?
      answer_means_safe ? "bg-green-100 dark:bg-green-900/20 font-semibold text-green-800 dark:text-green-300" : "bg-red-100 dark:bg-red-900/20 font-semibold text-red-800 dark:text-red-300"
    else
      "text-slate-400 dark:text-slate-500"
    end
  end

  def logic_no_classes
    return "text-slate-500 dark:text-slate-400" unless selected_answer
    if selected_answer == "no"
      answer_means_safe = !@item.yes_means_safe?
      answer_means_safe ? "bg-green-100 dark:bg-green-900/20 font-semibold text-green-800 dark:text-green-300" : "bg-red-100 dark:bg-red-900/20 font-semibold text-red-800 dark:text-red-300"
    else
      "text-slate-400 dark:text-slate-500"
    end
  end

  def evidence_present?
    auto_or_ai_source? && @result.evidence.present?
  end

  def evidence
    ev = @result.evidence
    ev.is_a?(String) ? JSON.parse(ev) : ev
  end

  def evidence_border_classes
    if @result.has_risk
      "border-l-red-500 bg-red-500/5 dark:bg-red-500/10"
    else
      "border-l-indigo-500 bg-indigo-500/5 dark:bg-indigo-500/10"
    end
  end

  def evidence_header_classes
    if @result.has_risk
      "text-red-400"
    else
      "text-indigo-400"
    end
  end

  def evidence_label_classes
    if @result.has_risk
      "text-red-300 dark:text-red-400"
    else
      "text-indigo-300 dark:text-indigo-400"
    end
  end

  def evidence_value_classes
    "text-slate-200 dark:text-slate-200 font-medium"
  end

  def keyword_result_classes
    if @result.has_risk
      "text-red-400 font-semibold"
    else
      "text-green-400"
    end
  end
end
