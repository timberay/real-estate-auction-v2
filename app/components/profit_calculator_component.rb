# frozen_string_literal: true

class ProfitCalculatorComponent < ViewComponent::Base
  def initialize(property:, budget_setting:, report:, show_title: true)
    @property = property
    @budget = budget_setting
    @report = report
    @show_title = show_title
  end

  # All values normalized to 만원 for the Stimulus controller
  def min_bid_manwon
    @property.min_bid_price.to_i / 10000
  end

  def appraisal_manwon
    @property.appraisal_price.to_i / 10000
  end

  def assumed_amount
    @report&.assumed_amount.to_i / 10000
  end

  def scrivener_fee
    @budget&.scrivener_fee.to_i
  end

  def repair_cost
    @budget&.repair_cost.to_i
  end

  def moving_cost
    @budget&.moving_cost.to_i
  end

  def maintenance_fee
    @budget&.maintenance_fee.to_i
  end

  # F-B — feed per-bracket acquisition tax data into the Stimulus controller
  # so the bid slider drives bracket-accurate rates instead of the legacy
  # flat effective-rate constants. Returns a hash keyed by household_tier;
  # each value is an ordered array of {rate, max} pairs (rate as decimal,
  # max in 만원, nil for the open-ended top bracket).
  def acquisition_tax_brackets
    return {} unless @budget&.property_type_id
    area_over_85 = @property.exclusive_area.to_f >= 85
    regulated = @budget.regulated_region?
    AcquisitionTaxRate::HOUSEHOLD_TIERS.index_with do |tier|
      AcquisitionTaxCalculator.brackets_for(
        property_type_id: @budget.property_type_id,
        household_tier: tier,
        regulated_region: regulated,
        area_over_85: area_over_85
      )
    end
  end

  # F-C-1 — opt-in flag for the precise 6~9억 progressive formula.
  # When true, the JS controller switches from a flat bracket rate to
  # `(가액(억) × 2/3 − 3) / 100` within the 6~9억 range.
  def precise_acquisition_tax?
    @budget&.acquisition_tax_precise_mode == true
  end

  # Re-derived from the property record so the JS can reapply the
  # 농어촌특별세 surcharge on top of the precise formula. Mirrors the
  # filter used in `acquisition_tax_brackets` so a single source of truth
  # drives both bracket selection and surcharge.
  def area_over_85?
    @property.exclusive_area.to_f >= 85
  end

  HOUSEHOLD_TIER_LABELS = {
    "homeless" => "무주택",
    "single_home" => "1주택",
    "multi_home_2" => "2주택",
    "multi_home_3plus" => "3주택 이상"
  }.freeze

  def ownership_options
    HOUSEHOLD_TIER_LABELS
  end

  def default_household_tier
    @budget&.household_tier.presence || "homeless"
  end

  # B25 / audit B-19 — tooltip copy for tax-treatment terminology shown
  # in the breakdown table 비고 column.
  TAX_TERM_TOOLTIPS = {
    "필요경비"        => "수선비·취득세 등은 양도세 계산 시 차감 가능",
    "필요경비만 공제" => "수선비·취득세 등은 양도세 계산 시 차감 가능",
    "경비 불산입"     => "양도세 계산 시 차감 불가 (지출했지만 공제 안 됨)"
  }.freeze

  TAX_TERM_TOOLTIP_ICON = <<~HTML.html_safe.freeze
    <svg class="inline w-3 h-3 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/>
    </svg>
  HTML

  # Renders a "?" tooltip span around a tax-term label. Mirrors the
  # PropertyCardComponent tooltip pattern for visual consistency.
  def tax_term_tooltip(term)
    copy = TAX_TERM_TOOLTIPS.fetch(term)
    helpers.tag.span(
      class: "relative inline-flex items-center gap-0.5 cursor-help",
      data: {
        controller: "tooltip",
        tooltip_content_value: copy,
        action: "mouseenter->tooltip#show mouseleave->tooltip#hide"
      }
    ) do
      helpers.safe_join([ term, TAX_TERM_TOOLTIP_ICON ])
    end
  end
end
