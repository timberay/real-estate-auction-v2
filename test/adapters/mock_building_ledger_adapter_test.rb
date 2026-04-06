require "test_helper"

class MockBuildingLedgerAdapterTest < ActiveSupport::TestCase
  setup do
    @adapter = MockBuildingLedgerAdapter.new
  end

  test "returns predefined data for known case numbers" do
    data = @adapter.fetch_data(case_number: "2026타경10001")
    assert_equal "아파트", data[:usage_type]
  end

  test "generates data for unknown case numbers" do
    data = @adapter.fetch_data(case_number: "2026타경99999")
    assert_not_nil data
    assert_includes ["아파트", "빌라", "오피스텔", "근린생활시설", "사무소"], data[:usage_type]
    assert_includes [true, false], data[:violation_flag]
  end

  test "generates deterministic data for same case number" do
    data1 = @adapter.fetch_data(case_number: "2026타경55555")
    data2 = @adapter.fetch_data(case_number: "2026타경55555")
    assert_equal data1, data2
  end
end
