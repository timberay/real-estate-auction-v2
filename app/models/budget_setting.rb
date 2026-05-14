class BudgetSetting < ApplicationRecord
  belongs_to :user
  belongs_to :property_type, optional: true
  belongs_to :loan_policy, optional: true

  HOUSEHOLD_TIERS = AcquisitionTaxRate::HOUSEHOLD_TIERS

  validates :user_id, uniqueness: true
  validates :available_cash, numericality: { greater_than: 0 }, allow_nil: true
  validates :loan_ratio, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :household_tier, inclusion: { in: HOUSEHOLD_TIERS }
  RESERVE_FIELDS = %i[repair_cost acquisition_tax scrivener_fee moving_cost maintenance_fee].freeze

  RESERVE_FIELDS.each do |field|
    validates field, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end

  # T1.5 — DSR 입력. 미입력 시 DsrCalculator 가 nil 반환하여 경고 배너가
  # 자체 숨김. 단위는 만원 (다른 reserve 필드와 일관).
  validates :annual_income, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :existing_debt_monthly, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def dsr_inputs_complete?
    annual_income.to_i.positive?
  end
  REGIONS = Regions::ALL
  DEFAULT_REGION = Regions::DEFAULT

  PRICE_OPTIONS = Pricing::PRICE_TIERS_WON
  DEFAULT_MAX_PRICE = Pricing::DEFAULT_MAX_PRICE_WON

  validates :region, inclusion: { in: REGIONS }, allow_nil: true
  AREA_CATEGORIES = [
    { key: "small",     label: "소형 (10~15평 / ~40㎡)",     min_sqm: 0,   max_sqm: 40 },
    { key: "mid_small", label: "중소형 (20~25평 / 40~60㎡)", min_sqm: 40,  max_sqm: 60 },
    { key: "mid",       label: "중형 (30~34평 / 60~85㎡)",   min_sqm: 60,  max_sqm: 85 },
    { key: "mid_large", label: "중대형 (38~42평 / 85~102㎡)", min_sqm: 85,  max_sqm: 102 },
    { key: "large",     label: "대형 (45평~ / 102㎡~)",      min_sqm: 102, max_sqm: 150 }
  ].freeze

  # Return options for a single select dropdown: [[label, key], ...]
  def self.area_category_options
    AREA_CATEGORIES.map { |c| [ c[:label], c[:key] ] }
  end

  # Find category by key and return its min/max sqm.
  def self.area_range_for(key)
    cat = AREA_CATEGORIES.find { |c| c[:key] == key }
    return {} unless cat

    { min: cat[:min_sqm], max: cat[:max_sqm] }
  end

  DEFAULT_AREA_CATEGORY = "small"

  # Derive the selected category key from stored min/max values.
  # Falls back to DEFAULT_AREA_CATEGORY when no exact match found.
  def selected_area_category
    return DEFAULT_AREA_CATEGORY unless area_range_min.present? && area_range_max.present?

    match = AREA_CATEGORIES.find { |c| c[:min_sqm] == area_range_min && c[:max_sqm] == area_range_max }
    match&.dig(:key) || DEFAULT_AREA_CATEGORY
  end

  def completed?
    completed_at.present?
  end

  def total_reserves
    RESERVE_FIELDS.sum { |field| public_send(field).to_i }
  end

  def max_price_option
    return DEFAULT_MAX_PRICE unless max_bid_amount
    target = max_bid_amount * 10_000
    PRICE_OPTIONS.find { |v| v >= target } || PRICE_OPTIONS.last
  end

  def effective_region
    region.presence || DEFAULT_REGION
  end

  def regulated_region?
    Regions.regulated?(region)
  end

  def area_over_85?
    area_range_min.to_i >= 85
  end
end
