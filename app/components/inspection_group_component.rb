class InspectionGroupComponent < ViewComponent::Base
  def initialize(category:, results:, dependency_hidden_ids: Set.new, beginner_mode: false)
    @category = category
    @results = results
    @dependency_hidden_ids = dependency_hidden_ids
    @beginner_mode = beginner_mode
  end

  private

  def risk_count = @results.count { |r| r.has_risk }
end
