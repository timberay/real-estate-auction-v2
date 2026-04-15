class InspectionGroupComponent < ViewComponent::Base
  def initialize(category:, results:, dependency_hidden_ids: Set.new)
    @category = category
    @results = results
    @dependency_hidden_ids = dependency_hidden_ids
  end

  private

  def risk_count = @results.count { |r| r.has_risk }
end
