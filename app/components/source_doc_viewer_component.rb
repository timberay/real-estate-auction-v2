class SourceDocViewerComponent < ViewComponent::Base
  def initialize(report:, property: nil)
    @report = report
    @property = property
    @source_doc_reviewed = report&.source_doc_reviewed || false
    @review_url = property ? Rails.application.routes.url_helpers.property_inspections_source_doc_review_path(property) : ""
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
