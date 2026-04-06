class DividendSimulatorComponent < ViewComponent::Base
  BURDEN_CONFIG = {
    "safe" => { color: "text-green-700 dark:text-green-400", bg: "bg-green-50 dark:bg-green-900/20", message: "추가 인수 부담이 없는 구조입니다" },
    "caution" => { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-50 dark:bg-yellow-900/20", message: "미확인 위험 금액이 존재합니다. 확인이 필요합니다" },
    "danger" => { color: "text-red-700 dark:text-red-400", bg: "bg-red-50 dark:bg-red-900/20", message: "인수 금액이 추가 발생하는 구조입니다" }
  }.freeze

  def initialize(report:, property:)
    @report = report
    @property = property
    @simulation = report.report_data&.dig("dividend_simulation") || {}
    @burden = report.report_data&.dig("bidder_burden") || {}
  end

  private

  def expected_bid
    @simulation["expected_bid"]
  end

  def distribution
    @simulation["distribution"] || []
  end

  def burden_config
    BURDEN_CONFIG[@burden["verdict"]] || BURDEN_CONFIG["safe"]
  end

  def format_amount(amount)
    return "—" if amount.nil?
    amount.to_fs(:delimited)
  end
end
