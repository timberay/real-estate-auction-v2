class InspectionGroupComponent < ViewComponent::Base
  def initialize(category:, results:)
    @category = category
    @results = results
  end

  private

  def risk_count = @results.count { |r| r.has_risk }
end
