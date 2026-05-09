class RightsReportSectionComponent < ViewComponent::Base
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
end
