class BudgetSetting < ApplicationRecord
  belongs_to :user
  belongs_to :property_type, optional: true
  belongs_to :loan_policy, optional: true

  validates :user_id, uniqueness: true
  validates :available_cash, numericality: { greater_than: 0 }, allow_nil: true
  validates :loan_ratio, numericality: { greater_than: 0, less_than_or_equal_to: 1 }, allow_nil: true
  validates :failed_auction_rounds, numericality: {
    only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 3
  }
  RESERVE_FIELDS = %i[repair_cost acquisition_tax scrivener_fee moving_cost maintenance_fee].freeze
  AREA_CATEGORIES = [
    { key: "small",     label: "소형 (10~15평 / ~40㎡)",     min_sqm: 0,   max_sqm: 40 },
    { key: "mid_small", label: "중소형 (20~25평 / 40~60㎡)", min_sqm: 40,  max_sqm: 60 },
    { key: "mid",       label: "중형 (30~34평 / 60~85㎡)",   min_sqm: 60,  max_sqm: 85 },
    { key: "mid_large", label: "중대형 (38~42평 / 85~102㎡)", min_sqm: 85,  max_sqm: 102 },
    { key: "large",     label: "대형 (45평~ / 102㎡~)",      min_sqm: 102, max_sqm: 150 }
  ].freeze

  # Compute area_range_min/max from an array of selected category keys.
  def self.area_range_from_categories(keys)
    selected = AREA_CATEGORIES.select { |c| keys.include?(c[:key]) }
    return {} if selected.empty?

    { min: selected.min_by { |c| c[:min_sqm] }[:min_sqm],
      max: selected.max_by { |c| c[:max_sqm] }[:max_sqm] }
  end

  # Derive selected category keys from stored min/max values.
  def selected_area_categories
    return [] unless area_range_min.present? && area_range_max.present?

    AREA_CATEGORIES.select { |c| c[:min_sqm] >= area_range_min && c[:max_sqm] <= area_range_max }.map { |c| c[:key] }
  end

  def completed?
    completed_at.present?
  end

  def total_reserves
    RESERVE_FIELDS.sum { |field| public_send(field).to_i }
  end
end
