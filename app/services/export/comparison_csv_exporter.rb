require "csv"

module Export
  class ComparisonCsvExporter
    HEADERS = %w[사건번호 법원 소재지 감정가 최저가 유찰횟수 다음매각기일 종합판정 인수금액 임차인수 예상차익].freeze

    VERDICT_LABELS = {
      safe: "안전",
      caution: "주의",
      danger: "위험",
      incomplete: "미완료"
    }.freeze

    def initialize(user_properties:, user:)
      @user_properties = user_properties
      @user = user
    end

    def to_csv
      reports = RightsAnalysisReport
        .where(user: @user, property_id: @user_properties.map(&:property_id))
        .index_by(&:property_id)

      bom = "\xEF\xBB\xBF"
      bom + CSV.generate(encoding: "UTF-8") do |csv|
        csv << HEADERS
        @user_properties.each do |up|
          csv << build_row(up, reports[up.property_id])
        end
      end
    end

    private

    def build_row(user_property, report)
      property = user_property.property
      verdict = InspectionRatingService.new(property: property, user: @user).overall_rating
      margin = property.appraisal_price.to_i - property.min_bid_price.to_i - report&.total_risk_amount.to_i

      [
        property.case_number,
        property.court_name,
        property.address,
        property.appraisal_price,
        property.min_bid_price,
        property.failed_bid_count,
        property.next_auction_schedule&.schedule_date&.iso8601,
        VERDICT_LABELS[verdict],
        report&.total_risk_amount,
        report ? report.effective_tenants.size : 0,
        margin
      ]
    end
  end
end
