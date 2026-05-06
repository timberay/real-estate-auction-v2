class ReportSummaryComponent < ViewComponent::Base
  VERDICT_CONFIG = {
    "safe" => { color: "text-green-700 dark:text-green-400", bg: "bg-green-100 dark:bg-green-900/20", border: "border-green-400", emoji: "🟢", label: "안전" },
    "caution" => { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-100 dark:bg-yellow-900/20", border: "border-yellow-400", emoji: "🟡", label: "주의" },
    "danger" => { color: "text-red-700 dark:text-red-400", bg: "bg-red-100 dark:bg-red-900/20", border: "border-red-400", emoji: "🔴", label: "위험" }
  }.freeze

  CHECKLIST_CODE_LABELS = {
    "rights-003" => "선순위 전세권 위험",
    "rights-006" => "대항력 있는 임차인 위험",
    "rights-009" => "HUG 확약서 미제출",
    "rights-011" => "유치권 신고 있음"
  }.freeze

  def initialize(report:, property:)
    @report = report
    @property = property
    @config = VERDICT_CONFIG[report.verdict] || VERDICT_CONFIG["safe"]
  end

  private

  def opportunity?
    @report.opportunity_type.present?
  end

  def checklist_summary
    data = @report.report_data
    data = JSON.parse(data) if data.is_a?(String)
    refs = data&.dig("checklist_references") || []
    return "위험 항목 없음" if refs.empty?

    refs.map { |code| CHECKLIST_CODE_LABELS[code] || code }.join(", ")
  end

  def format_price(price_in_won)
    helpers.format_price_won(price_in_won)
  end
end
