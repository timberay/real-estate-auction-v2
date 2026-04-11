class RightsAnalysisReport < ApplicationRecord
  belongs_to :user
  belongs_to :property

  enum :verdict, { safe: 0, caution: 1, danger: 2 }

  validates :user_id, uniqueness: { scope: :property_id }
  validates :analyzed_at, presence: true

  def effective_tenants
    parsed_data&.dig("calculated", "tenants") || parsed_data&.dig("tenants") || []
  end

  def effective_rights_timeline
    parsed_data&.dig("llm_raw", "rights_timeline") || parsed_data&.dig("rights_timeline") || []
  end

  def discrepancies
    parsed_data&.dig("discrepancies") || []
  end

  def parsed_data
    return nil if report_data.nil?
    return report_data if report_data.is_a?(Hash)
    JSON.parse(report_data)
  rescue JSON::ParserError
    {}
  end
end
