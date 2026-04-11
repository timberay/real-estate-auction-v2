class SourceDocViewerComponent < ViewComponent::Base
  def initialize(report:)
    @report = report
  end

  private

  def tenants
    @report&.effective_tenants || []
  end

  def tenants_with_opposing_power
    tenants.count { |t| t["opposing_power"] }
  end

  def rights_timeline
    @report&.effective_rights_timeline || []
  end

  def extraction_failed?
    @report&.parsed_data&.dig("analysis_status") == "extraction_failed"
  end

  def has_data?
    @report.present? && !extraction_failed?
  end
end
