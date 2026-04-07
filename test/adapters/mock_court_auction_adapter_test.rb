require "test_helper"

class MockCourtAuctionAdapterTest < ActiveSupport::TestCase
  setup do
    @adapter = MockCourtAuctionAdapter.new
  end

  test "returns predefined data for known case numbers" do
    data = @adapter.fetch_data(case_number: "2026타경10001")
    assert_equal "서울중앙지방법원", data[:court_name]
    assert_equal "아파트", data[:property_type]
  end

  test "generates data for unknown case numbers" do
    data = @adapter.fetch_data(case_number: "2026타경99999")
    assert_not_nil data
    assert_equal "2026타경99999", data[:case_number]
    assert_includes [ "아파트", "빌라", "오피스텔" ], data[:property_type]
    assert data[:appraisal_price].is_a?(Integer)
    assert data[:appraisal_price] > 0
  end

  test "generates deterministic data for same case number" do
    data1 = @adapter.fetch_data(case_number: "2026타경55555")
    data2 = @adapter.fetch_data(case_number: "2026타경55555")
    assert_equal data1, data2
  end

  test "generates different data for different case numbers" do
    data1 = @adapter.fetch_data(case_number: "2026타경55555")
    data2 = @adapter.fetch_data(case_number: "2026타경66666")
    assert_not_equal data1[:address], data2[:address]
  end
end
