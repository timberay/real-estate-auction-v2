class RightsReportSectionComponent < ViewComponent::Base
  def initialize(report:, property:)
    @report = report
    @property = property
  end
end
