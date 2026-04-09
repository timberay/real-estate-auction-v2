require "test_helper"

class CourtAuctionAdapterTest < ActiveSupport::TestCase
  test ".for returns MockCourtAuctionAdapter by default" do
    adapter = CourtAuctionAdapter.for
    assert_instance_of MockCourtAuctionAdapter, adapter
  end

  test ".for returns GovernmentCourtAuctionAdapter when adapter is :real" do
    adapter = CourtAuctionAdapter.for(adapter: :real)
    assert_instance_of GovernmentCourtAuctionAdapter, adapter
  end

  test "mock adapter returns data for known case_number" do
    adapter = MockCourtAuctionAdapter.new
    data = adapter.fetch_data(case_number: "2026타경10001")
    assert data.is_a?(Hash)
    assert data.key?(:remarks)
    assert data.key?(:tenants)
  end

  test "mock adapter generates data for unknown case_number" do
    adapter = MockCourtAuctionAdapter.new
    data = adapter.fetch_data(case_number: "unknown-999")
    assert_not_nil data
    assert_equal "unknown-999", data[:case_number]
  end
end
