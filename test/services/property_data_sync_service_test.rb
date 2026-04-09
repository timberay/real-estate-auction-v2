require "test_helper"

class PropertyDataSyncServiceTest < ActiveSupport::TestCase
  test "creates new property from adapters" do
    Property.find_by(case_number: "2026타경10001")&.destroy
    assert_difference "Property.count", 1 do
      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      property = result.property
      assert_equal "2026타경10001", property.case_number
      assert_equal "아파트", property.property_type
      assert_equal "서울특별시 강남구 역삼동 100-1", property.address
      assert_equal 80000, property.appraisal_price
      assert_equal 56000, property.min_bid_price
    end
  end

  test "upserts existing property without duplicating" do
    PropertyDataSyncService.call(case_number: "2026타경10001")
    assert_no_difference "Property.count" do
      result = PropertyDataSyncService.call(case_number: "2026타경10001")
      assert_equal "2026타경10001", result.property.case_number
    end
  end

  test "raw_data only contains building_ledger and registry_transcript" do
    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    property = result.property

    assert property.raw_data.key?("building_ledger")
    assert property.raw_data.key?("registry_transcript")
    assert_not property.raw_data.key?("court_auction"),
      "raw_data should not contain court_auction — court data goes into structured columns"
  end

  test "stores building_ledger in raw_data" do
    result = PropertyDataSyncService.call(case_number: "2026타경10002")
    property = result.property
    building_data = property.raw_data["building_ledger"]

    assert_equal true, building_data["violation_flag"]
  end

  test "stores registry_transcript in raw_data" do
    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    property = result.property
    transcript = property.raw_data["registry_transcript"]

    assert transcript.key?("rights")
    assert transcript.key?("tenants")
    assert transcript.key?("hug_waiver")
    assert transcript.key?("seizures")
  end

  test "maps mock adapter remarks to property.remarks column" do
    result = PropertyDataSyncService.call(case_number: "2026타경10002")
    property = result.property

    assert property.remarks.include?("유치권")
  end

  test "handles missing building ledger data gracefully" do
    result = PropertyDataSyncService.call(case_number: "2026타경10001")
    assert result.property.raw_data.key?("building_ledger")
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
