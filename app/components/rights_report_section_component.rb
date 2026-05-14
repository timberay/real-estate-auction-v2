class RightsReportSectionComponent < ViewComponent::Base
  # D2 — opportunity_type values that carry SAFE-opportunity semantics.
  # `preferred_purchase_risk` is excluded: it lives in the same column for
  # historical reasons but is rendered in a separate amber 위험 신호 box.
  SAFE_OPPORTUNITY_TYPES = %w[hug_waiver gap_investment occupancy].freeze

  def initialize(report:, property:, show_title: true)
    @report = report
    @property = property
    @show_title = show_title
  end

  # B8 / E-41: opportunity citation evidence stored in report_data JSON.
  # Returns the hash with source_doc / page_number / quote, or nil when absent.
  def opportunity_evidence
    @report.parsed_data&.dig("opportunity_evidence")
  end

  def safe_opportunity?
    SAFE_OPPORTUNITY_TYPES.include?(@report.opportunity_type)
  end

  def risk_signal?
    @report.opportunity_type == "preferred_purchase_risk"
  end
end
