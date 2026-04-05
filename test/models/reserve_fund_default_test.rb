require "test_helper"

class ReserveFundDefaultTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    rfd = ReserveFundDefault.new(
      property_type: property_types(:apartment),
      area_range_min: 59, area_range_max: 84,
      repair_cost: 763, acquisition_tax_rate: 0.011,
      scrivener_fee: 80, moving_cost: 255, maintenance_fee: 0
    )
    assert rfd.valid?
  end

  test "invalid without property_type" do
    rfd = ReserveFundDefault.new(
      property_type: nil, area_range_min: 59, area_range_max: 84,
      repair_cost: 763, acquisition_tax_rate: 0.011,
      scrivener_fee: 80, moving_cost: 255, maintenance_fee: 0
    )
    assert_not rfd.valid?
  end

  test "invalid when area_range_min >= area_range_max" do
    rfd = ReserveFundDefault.new(
      property_type: property_types(:apartment),
      area_range_min: 84, area_range_max: 59,
      repair_cost: 763, acquisition_tax_rate: 0.011,
      scrivener_fee: 80, moving_cost: 255, maintenance_fee: 0
    )
    assert_not rfd.valid?
    assert_includes rfd.errors[:area_range_max], "must be greater than area_range_min"
  end

  test "scope for_property_type_and_area finds matching default" do
    ReserveFundDefault.delete_all
    apt = property_types(:apartment)
    ReserveFundDefault.create!(
      property_type: apt, area_range_min: 59, area_range_max: 84,
      repair_cost: 763, acquisition_tax_rate: 0.011,
      scrivener_fee: 80, moving_cost: 255, maintenance_fee: 0
    )
    ReserveFundDefault.create!(
      property_type: apt, area_range_min: 85, area_range_max: 135,
      repair_cost: 1226, acquisition_tax_rate: 0.011,
      scrivener_fee: 100, moving_cost: 409, maintenance_fee: 0
    )
    result = ReserveFundDefault.for_property_type_and_area(apt.id, 70)
    assert_equal 763, result.repair_cost
    result = ReserveFundDefault.for_property_type_and_area(apt.id, 100)
    assert_equal 1226, result.repair_cost
  end
end
