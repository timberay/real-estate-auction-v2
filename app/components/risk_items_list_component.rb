class RiskItemsListComponent < ViewComponent::Base
  def initialize(risk_results:)
    @unresolvable = risk_results.select { |r| r.resolvable == false }
    @resolvable = risk_results.select { |r| r.resolvable == true }
    @unevaluated = risk_results.select { |r| r.resolvable.nil? }
  end
end
