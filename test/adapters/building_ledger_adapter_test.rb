require "test_helper"

class BuildingLedgerAdapterTest < ActiveSupport::TestCase
  test ".for returns MockBuildingLedgerAdapter by default" do
    adapter = BuildingLedgerAdapter.for
    assert_instance_of MockBuildingLedgerAdapter, adapter
  end

  test "mock adapter returns building data for known case_number" do
    adapter = MockBuildingLedgerAdapter.new
    data = adapter.fetch_data(case_number: "2026타경10002")
    assert data.is_a?(Hash)
    assert data.key?(:usage_type)
    assert data.key?(:violation_flag)
  end
end
