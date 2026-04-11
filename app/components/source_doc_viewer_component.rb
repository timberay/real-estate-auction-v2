class SourceDocViewerComponent < ViewComponent::Base
  def initialize(report:)
    @report = report
    @report_data = parse_report_data(report&.report_data)
  end

  private

  def parse_report_data(data)
    return {} if data.blank?
    data.is_a?(String) ? JSON.parse(data) : data
  rescue JSON::ParserError
    {}
  end

  def tenants
    (@report_data["tenants"] || []).tap do |tenants|
      break [] unless tenants.is_a?(Array)
    end
  end

  def tenants_with_opposing_power
    tenants.select { |t| t["opposing_power"] }.count
  end

  def rights_timeline
    (@report_data["rights_timeline"] || []).tap do |timeline|
      break [] unless timeline.is_a?(Array)
    end
  end

  def extraction_failed?
    @report_data["analysis_status"] == "extraction_failed"
  end

  def has_data?
    @report.present? && !extraction_failed?
  end
end
