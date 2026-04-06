class ReportSummaryComponent < ViewComponent::Base
  VERDICT_CONFIG = {
    "safe" => { color: "text-green-700 dark:text-green-400", bg: "bg-green-50 dark:bg-green-900/20", border: "border-green-300", emoji: "🟢", label: "안전" },
    "caution" => { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-50 dark:bg-yellow-900/20", border: "border-yellow-300", emoji: "🟡", label: "주의" },
    "danger" => { color: "text-red-700 dark:text-red-400", bg: "bg-red-50 dark:bg-red-900/20", border: "border-red-300", emoji: "🔴", label: "위험" }
  }.freeze

  def initialize(report:)
    @report = report
    @config = VERDICT_CONFIG[report.verdict] || VERDICT_CONFIG["safe"]
  end

  private

  def opportunity?
    @report.opportunity_type.present?
  end

  def format_amount(amount)
    return "0원" if amount.nil? || amount == 0
    amount.to_fs(:delimited) + "원"
  end
end
