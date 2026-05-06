class GradeSummaryComponent < ViewComponent::Base
  RATING_CONFIG = {
    safe: { color: "text-green-700 dark:text-green-400", bg: "bg-green-100 dark:bg-green-900/20 border-green-400 dark:border-green-700", label: "안전", description: "위험 항목이 없습니다" },
    caution: { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-100 dark:bg-yellow-900/20 border-yellow-400 dark:border-yellow-700", label: "주의", description: "위험 항목이 있으나 모두 해결 가능합니다" },
    danger: { color: "text-red-700 dark:text-red-400", bg: "bg-red-100 dark:bg-red-900/20 border-red-400 dark:border-red-700", label: "경고", description: "해결 불가능한 위험 항목이 있습니다" },
    incomplete: { color: "text-slate-500 dark:text-slate-400", bg: "bg-slate-100 dark:bg-slate-800/50 border-slate-400 dark:border-slate-600", label: "미평가", description: "아직 평가된 항목이 없습니다" }
  }.freeze

  def initialize(rating:, fully_evaluated: true, tabs_evaluated: nil, tabs_total: nil, compact: false)
    @config = RATING_CONFIG[rating] || RATING_CONFIG[:incomplete]
    @fully_evaluated = fully_evaluated
    @tabs_evaluated = tabs_evaluated
    @tabs_total = tabs_total
    @compact = compact
  end

  private

  def display_label
    if @fully_evaluated || @config[:label] == "미평가"
      @config[:label]
    else
      "#{@config[:label]} (진행 중)"
    end
  end

  def partial?
    !@fully_evaluated && @config[:label] != "미평가"
  end

  def progress_text
    return nil unless @tabs_evaluated && @tabs_total && !@fully_evaluated
    "#{@tabs_total}개 중 #{@tabs_evaluated}개 탭 분석 완료"
  end
end
