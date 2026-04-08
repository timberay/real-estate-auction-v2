class BudgetSetting < ApplicationRecord
  belongs_to :user
  belongs_to :property_type, optional: true
  belongs_to :loan_policy, optional: true

  validates :user_id, uniqueness: true
  validates :available_cash, numericality: { greater_than: 0 }, allow_nil: true
  validates :loan_ratio, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, allow_nil: true
  RESERVE_FIELDS = %i[repair_cost acquisition_tax scrivener_fee moving_cost maintenance_fee].freeze
  AREA_CATEGORIES = [
    { key: "small",     label: "소형 (10~15평 / ~40㎡)",     min_sqm: 0,   max_sqm: 40 },
    { key: "mid_small", label: "중소형 (20~25평 / 40~60㎡)", min_sqm: 40,  max_sqm: 60 },
    { key: "mid",       label: "중형 (30~34평 / 60~85㎡)",   min_sqm: 60,  max_sqm: 85 },
    { key: "mid_large", label: "중대형 (38~42평 / 85~102㎡)", min_sqm: 85,  max_sqm: 102 },
    { key: "large",     label: "대형 (45평~ / 102㎡~)",      min_sqm: 102, max_sqm: 150 }
  ].freeze

  # Return options for a single select dropdown: [[label, key], ...]
  def self.area_category_options
    AREA_CATEGORIES.map { |c| [c[:label], c[:key]] }
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
end
