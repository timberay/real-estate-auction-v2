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
    @checklist_refs ||= ChecklistCodeMapping.build_checklist_refs(@report.checklist_reference_codes)
  end

  def format_price(price_in_won)
    helpers.format_price_won(price_in_won)
  end
end
