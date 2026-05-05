class BudgetSetting < ApplicationRecord
  belongs_to :user
  belongs_to :property_type, optional: true
  belongs_to :loan_policy, optional: true

  validates :user_id, uniqueness: true
  validates :available_cash, numericality: { greater_than: 0 }, allow_nil: true
  validates :loan_ratio, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, allow_nil: true
  RESERVE_FIELDS = %i[repair_cost acquisition_tax scrivener_fee moving_cost maintenance_fee].freeze

  RESERVE_FIELDS.each do |field|
    validates field, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end
  REGIONS = [
    "서울특별시", "부산광역시", "대구광역시", "인천광역시", "광주광역시",
    "대전광역시", "울산광역시", "세종특별자치시", "경기도", "강원도",
    "충청북도", "충청남도", "전라북도", "전라남도", "경상북도",
    "경상남도", "제주특별자치도", "강원특별자치도", "전북특별자치도"
  ].freeze

  DEFAULT_REGION = "제주특별자치도"

  PRICE_OPTIONS = [
    10_000_000, 50_000_000, 100_000_000, 150_000_000,
    200_000_000, 250_000_000, 300_000_000, 350_000_000,
    400_000_000, 450_000_000, 500_000_000, 550_000_000,
    600_000_000, 650_000_000, 700_000_000, 750_000_000,
    800_000_000, 850_000_000, 900_000_000, 950_000_000,
    1_000_000_000
  ].freeze

  DEFAULT_MAX_PRICE = 500_000_000

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
    LoanPolicy::REGULATED_REGIONS.include?(region)
  end
end
