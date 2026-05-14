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
      rights_timeline: @report.effective_rights_timeline,
      property: @property
    )
  end

  def small_tenant_period_caption
    info = distribution_result.small_tenant_period
    return nil unless info
    tier_label = tier_label_for(info[:tier])
    deposit_cap_man = (info[:deposit_cap].to_i / 10_000)
    protection_man = (info[:protection_amount].to_i / 10_000)
    "소액임차인 한도 (#{tier_label} / #{info[:period_label]}): " \
      "보증금 ≤ #{number_with_delimiter(deposit_cap_man)}만원 → 최우선변제 #{number_with_delimiter(protection_man)}만원"
  end

  TIER_LABELS = {
    "seoul" => "서울특별시",
    "overcrowded" => "과밀억제권역·세종·용인·화성·김포 등",
    "metro" => "광역시·안산·광주·파주·이천·평택 등",
    "other" => "그 밖의 지역"
  }.freeze

  def tier_label_for(tier)
    TIER_LABELS[tier.to_s] || tier.to_s
  end

  def number_with_delimiter(value)
    helpers.number_with_delimiter(value)
  end
end
