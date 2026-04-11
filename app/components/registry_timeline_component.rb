class RegistryTimelineComponent < ViewComponent::Base
  def initialize(report:)
    @report = report
    @timeline = report.effective_rights_timeline
    @tenants = report.effective_tenants
    @checklist_refs = report.report_data&.dig("llm_raw", "checklist_references") ||
                      report.report_data&.dig("checklist_references") || []
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
