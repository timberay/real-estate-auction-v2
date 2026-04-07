class InspectionItemComponent < ViewComponent::Base
  def initialize(result:, show_resolution: false)
    @result = result
    @item = result.inspection_item
    @show_resolution = show_resolution
  end

  private

  def auto_source? = @result.source_type == "auto"
  def manual_source? = !auto_source?

  def risk_classes
    if manual_source? && @result.has_risk.nil?
      "border-slate-300 bg-slate-50 dark:border-slate-600 dark:bg-slate-800/50"
    elsif @result.has_risk
      auto_source? ? "border-red-300 bg-red-50 dark:border-red-600 dark:bg-red-900/20" : "border-yellow-300 bg-yellow-50 dark:border-yellow-600 dark:bg-yellow-900/20"
    else
      "border-green-300 bg-green-50 dark:border-green-600 dark:bg-green-900/20"
    end
  end

  def source_badge_text = auto_source? ? "AUTO" : "직접 확인"

  def status_text
    if manual_source? && @result.has_risk.nil? then "미입력"
    elsif @result.has_risk then auto_source? ? "위험" : "위험 확인"
    else "안전"
    end
  end

  def show_auto_resolution? = @show_resolution && auto_source? && @result.has_risk
  def show_manual_input? = @show_resolution && manual_source?
end
