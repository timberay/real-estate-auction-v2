require "test_helper"

class PropertyDataSyncServiceTest < ActiveSupport::TestCase
  test "creates new property from adapters" do
    Property.find_by(case_number: "2026타경10001")&.destroy
    assert_difference "Property.count", 1 do
      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      property = result.property
      assert_equal "2026타경10001", property.case_number
      assert_equal "서울중앙지방법원", property.court_name
      assert property.raw_data.key?("court_auction")
      assert property.raw_data.key?("building_ledger")
    end
  end

  test "upserts existing property without duplicating" do
    PropertyDataSyncService.call(case_number: "2026타경10001")
    assert_no_difference "Property.count" do
      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_equal "2026타경10001", result.property.case_number
    end
  end

  test "stores raw_data from both adapters" do
    result = PropertyDataSyncService.call(case_number: "2026타경10002")
    property = result.property
    court_data = property.raw_data["court_auction"]
    building_data = property.raw_data["building_ledger"]

    assert court_data["remarks"].include?("유치권")
    assert_equal true, building_data["violation_flag"]
  end

  test "handles missing building ledger data gracefully" do
    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    assert result.property.raw_data.key?("building_ledger")
  end

  test "includes registry_transcript in raw_data" do
    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    property = result.property
    assert property.raw_data.key?("registry_transcript")
    transcript = property.raw_data["registry_transcript"]
    assert transcript.key?("rights")
    assert transcript.key?("tenants")
    assert transcript.key?("hug_waiver")
    assert transcript.key?("seizures")
  end

  test "accepts user parameter" do
    user = users(:guest)
    result = PropertyDataSyncService.call(case_number: "2026타경10001", user: user)
    assert result.court_data.present?
    assert result.property.present?
  end

  test "returns Result with court_data, building_data, registry_data, errors" do
    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    assert_respond_to result, :court_data
    assert_respond_to result, :building_data
    assert_respond_to result, :registry_data
    assert_respond_to result, :errors
    assert_respond_to result, :property
  end

  test "errors hash is empty on full success" do
    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    assert_empty result.errors
  end
end
