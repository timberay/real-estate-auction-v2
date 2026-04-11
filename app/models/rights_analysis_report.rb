class RightsAnalysisReport < ApplicationRecord
  belongs_to :user
  belongs_to :property

  enum :verdict, { safe: 0, caution: 1, danger: 2 }

  validates :user_id, uniqueness: { scope: :property_id }
  validates :analyzed_at, presence: true

  def effective_tenants
    report_data&.dig("calculated", "tenants") || report_data&.dig("tenants") || []
  end

  def effective_rights_timeline
    report_data&.dig("llm_raw", "rights_timeline") || report_data&.dig("rights_timeline") || []
  end

  def discrepancies
    report_data&.dig("discrepancies") || []
  end
end
