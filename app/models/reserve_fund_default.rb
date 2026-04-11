class ReserveFundDefault < ApplicationRecord
  belongs_to :property_type
  validates :area_range_min, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :area_range_max, presence: true
  validates :repair_cost, :scrivener_fee, :moving_cost, :maintenance_fee,
            presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :acquisition_tax_rate, presence: true,
            numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 0.12 }
  validate :area_range_max_greater_than_min

  def self.for_property_type_and_area(property_type_id, area_sqm)
    where(property_type_id: property_type_id)
      .where("area_range_min <= ? AND area_range_max >= ?", area_sqm, area_sqm)
      .first
  end

  private

  def area_range_max_greater_than_min
    return unless area_range_min.present? && area_range_max.present?
    if area_range_max <= area_range_min
      errors.add(:area_range_max, "must be greater than area_range_min")
    end
  end
end
