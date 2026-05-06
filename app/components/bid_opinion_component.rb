class BidOpinionComponent < ViewComponent::Base
  include ApplicationHelper

  VERDICT_CONFIG = {
    safe: {
      label: "입찰 검토 가능합니다",
      bg: "bg-green-100 dark:bg-green-900/20 border-green-400 dark:border-green-700",
      text: "text-green-800 dark:text-green-200",
      icon_bg: "bg-green-100 dark:bg-green-800/40"
    },
    caution: {
      label: "입찰 검토 가능하나 확인 필요",
      bg: "bg-yellow-100 dark:bg-yellow-900/20 border-yellow-400 dark:border-yellow-700",
      text: "text-yellow-800 dark:text-yellow-200",
      icon_bg: "bg-yellow-100 dark:bg-yellow-800/40"
    },
    danger: {
      label: "입찰을 권하지 않습니다",
      bg: "bg-red-100 dark:bg-red-900/20 border-red-400 dark:border-red-700",
      text: "text-red-800 dark:text-red-200",
      icon_bg: "bg-red-100 dark:bg-red-800/40"
    },
    incomplete: {
      label: "분석이 완료되지 않았습니다",
      bg: "bg-slate-100 dark:bg-slate-800/50 border-slate-400 dark:border-slate-600",
      text: "text-slate-700 dark:text-slate-300",
      icon_bg: "bg-slate-100 dark:bg-slate-700"
    }
  }.freeze

  def initialize(rating:, report:, risk_results:, budget_setting:, property:)
    @rating = rating
    @report = report
    @risk_results = risk_results
    @budget = budget_setting
    @property = property
    @config = VERDICT_CONFIG[rating] || VERDICT_CONFIG[:incomplete]
  end

  private

  def reasoning
    case @rating
    when :danger
      unresolvable = @risk_results.select { |r| r.resolvable == false }
      items = unresolvable.map { |r| r.inspection_item.question }.join(", ")
      "해소 불가능한 위험 항목 #{unresolvable.size}건: #{items}"
    when :caution
      resolvable = @risk_results.select { |r| r.resolvable == true }
      "해소 가능한 위험 항목 #{resolvable.size}건. 전문가 확인 권장."
    when :safe
      "위험 항목이 없습니다."
    when :incomplete
      "미입력 항목이 있습니다. 분석 완료 후 재확인하세요."
    end
  end

  def key_figures
    figures = [
      { label: "감정가", value: format_price_won(@property.appraisal_price) },
      { label: "최저매각가격", value: format_price_won(@property.min_bid_price) }
    ]

    if @report
      figures << { label: "인수금액", value: format_price_won(@report.assumed_amount) }
      figures << { label: "총 위험금액", value: format_price_won(@report.total_risk_amount) }
      figures << { label: "대항력 있는 임차인", value: "#{opposing_tenant_count}명" }
    end

    if @budget
      figures << { label: "최대 입찰가 (예산)", value: format_price_in_eok(@budget.max_bid_amount) }
    end

    figures
  end

  def opposing_tenant_count
    return 0 unless @report
    @report.effective_tenants.count { |t| t["opposing_power"] }
  end
end
