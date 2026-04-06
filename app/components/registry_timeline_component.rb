class RegistryTimelineComponent < ViewComponent::Base
  def initialize(report:)
    @report = report
    @timeline = report.report_data&.dig("registry_timeline") || []
    @tenants = report.report_data&.dig("tenants") || []
    @checklist_refs = report.report_data&.dig("checklist_references") || []
  end

  private

  def base_right_date
    @report.base_right_date
  end

  def format_amount(amount)
    return "—" if amount.nil?
    amount.to_fs(:delimited) + "원"
  end
end
