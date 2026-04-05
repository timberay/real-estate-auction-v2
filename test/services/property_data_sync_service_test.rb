require "test_helper"

class PropertyDataSyncServiceTest < ActiveSupport::TestCase
  test "creates new property from adapters" do
    Property.find_by(case_number: "2026타경10001")&.destroy
    assert_difference "Property.count", 1 do
      property = PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_equal "2026타경10001", property.case_number
      assert_equal "서울중앙지방법원", property.court_name
      assert property.raw_data.key?("court_auction")
      assert property.raw_data.key?("building_ledger")
    end
  end

  test "upserts existing property without duplicating" do
    PropertyDataSyncService.call(case_number: "2026타경10001")
    assert_no_difference "Property.count" do
      property = PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_equal "2026타경10001", property.case_number
    end
  end

  test "stores raw_data from both adapters" do
    property = PropertyDataSyncService.call(case_number: "2026타경10002")
    court_data = property.raw_data["court_auction"]
    building_data = property.raw_data["building_ledger"]

    assert court_data["remarks"].include?("유치권")
    assert_equal true, building_data["violation_flag"]
  end

  test "handles missing building ledger data gracefully" do
    property = PropertyDataSyncService.call(case_number: "2026타경10001")
    assert property.raw_data.key?("building_ledger")
  end
end
