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
  validates :area_unit, inclusion: { in: %w[pyeong sqm] }
  validate :area_range_min_not_exceeding_max

  RESERVE_FIELDS = %i[repair_cost acquisition_tax scrivener_fee moving_cost maintenance_fee].freeze
  AREA_CATEGORIES = [
    { key: :small,      label: "소형 (10~15평 / ~40㎡)",          min_sqm: 0,   max_sqm: 40 },
    { key: :mid_small,  label: "중소형 (20~25평 / 40~60㎡)",      min_sqm: 40,  max_sqm: 60 },
    { key: :mid,        label: "중형 · 국평 (30~34평 / 60~85㎡)", min_sqm: 60,  max_sqm: 85 },
    { key: :mid_large,  label: "중대형 (38~42평 / 85~102㎡)",     min_sqm: 85,  max_sqm: 102 },
    { key: :large,      label: "대형 (45평~ / 102㎡~)",           min_sqm: 102, max_sqm: 150 }
  ].freeze
  SQM_PER_PYEONG = 3.305785

  def self.area_min_options
    AREA_CATEGORIES.map { |c| [ c[:label], c[:min_sqm] ] }
  end

  def self.area_max_options
    AREA_CATEGORIES.map { |c| [ c[:label], c[:max_sqm] ] }
  end

  def completed?
    completed_at.present?
  end

  def total_reserves
    RESERVE_FIELDS.sum { |field| public_send(field).to_i }
  end

  # Convert user-input area values to sqm for DB storage.
  # Call this after assign_attributes with form params.
  def convert_area_to_sqm!
    return unless area_unit == "pyeong" && area_range_min.present?

    self.area_range_min = (area_range_min * SQM_PER_PYEONG).round
    self.area_range_max = (area_range_max * SQM_PER_PYEONG).round if area_range_max.present?
  end

  private

  def area_range_min_not_exceeding_max
    return unless area_range_min.present? && area_range_max.present?
    if area_range_min > area_range_max
      errors.add(:area_range_min, "은(는) 면적 최대 이하여야 합니다")
    end
  end

  public

  # Return area values converted to the user's display unit.
  def display_area_min
    return area_range_min unless area_unit == "pyeong" && area_range_min.present?

    (area_range_min / SQM_PER_PYEONG).round
  end

  def display_area_max
    return area_range_max unless area_unit == "pyeong" && area_range_max.present?

    (area_range_max / SQM_PER_PYEONG).round
  end
end
