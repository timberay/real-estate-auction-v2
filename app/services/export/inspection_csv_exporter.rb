require "csv"

module Export
  class InspectionCsvExporter
    HEADERS = %w[사건번호 법원 소재지 감정가 최저가 유찰횟수 다음매각기일 종합판정 인수금액 임차인수 명도난이도 분석일시].freeze

    VERDICT_LABELS = {
      safe: "안전",
      caution: "주의",
      danger: "위험",
      incomplete: "미완료"
    }.freeze

    DIFFICULTY_LABELS = EvictionGuide::DifficultyBadgeComponent::VARIANTS.transform_values { |v| v[:label] }.freeze

    def initialize(property:, user:, verdict: nil)
      @property = property
      @user = user
      @verdict = verdict
    end

    def to_csv
      report = RightsAnalysisReport.find_by(property: @property, user: @user)
      simulation = EvictionSimulation.find_by(property: @property)
      verdict = @verdict || InspectionRatingService.new(property: @property, user: @user).overall_rating

      bom = "\xEF\xBB\xBF"
      bom + CSV.generate(encoding: "UTF-8") do |csv|
        csv << HEADERS
        csv << build_row(report, simulation, verdict)
      end
    end

    private

    def build_row(report, simulation, verdict)
      [
        @property.case_number,
        @property.court_name,
        @property.address,
        @property.appraisal_price,
        @property.min_bid_price,
        @property.failed_bid_count,
        @property.next_auction_schedule&.schedule_date&.iso8601,
        VERDICT_LABELS[verdict],
        report&.total_risk_amount,
        report ? report.effective_tenants.size : 0,
        simulation&.difficulty_level.then { |lvl| lvl ? DIFFICULTY_LABELS[lvl] : nil },
        report&.analyzed_at&.in_time_zone&.strftime("%Y-%m-%d %H:%M")
      ]
    end
  end
end
