class RightsReportSectionComponent < ViewComponent::Base
  def initialize(report:, property:, show_title: true)
    @report = report
    @property = property
    @show_title = show_title
  end
end
