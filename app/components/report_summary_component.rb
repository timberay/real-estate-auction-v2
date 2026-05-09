class ReportSummaryComponent < ViewComponent::Base
  def initialize(report:, property:, simulated_sale_price: nil)
    @report = report
    @property = property
    @simulated_sale_price = simulated_sale_price
  end

  private

  def opportunity?
    @report.opportunity_type.present?
  end

  def checklist_refs
    @checklist_refs ||= ChecklistCodeMapping.build_checklist_refs(@report.checklist_reference_codes)
  end

  def format_price(price_in_won)
    helpers.format_price_won(price_in_won)
  end

  def simulator_sale_price
    @simulated_sale_price.presence || @property.min_bid_price.to_i
  end

  def show_simulator?
    simulator_sale_price.to_i.positive? && @report.effective_tenants.any?
  end

  def distribution_result
    @distribution_result ||= Inspection::DistributionSimulator.call(
      sale_price: simulator_sale_price,
      validated_tenants: @report.effective_tenants,
      rights_timeline: @report.effective_rights_timeline
    )
  end
end
