class ReportSummaryComponent < ViewComponent::Base
  def initialize(report:, property:)
    @report = report
    @property = property
  end

  private

  def opportunity?
    @report.opportunity_type.present?
  end

  def checklist_refs
    data = @report.report_data
    data = JSON.parse(data) if data.is_a?(String)
    codes = data&.dig("checklist_references") || []
    ChecklistCodeMapping.build_checklist_refs(codes)
  end

  def format_price(price_in_won)
    helpers.format_price_won(price_in_won)
  end
end
