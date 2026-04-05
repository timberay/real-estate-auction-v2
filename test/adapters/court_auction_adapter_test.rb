require "test_helper"

class CourtAuctionAdapterTest < ActiveSupport::TestCase
  test ".for returns MockCourtAuctionAdapter by default" do
    adapter = CourtAuctionAdapter.for
    assert_instance_of MockCourtAuctionAdapter, adapter
  end

  test ".for returns GovernmentCourtAuctionAdapter when USE_MOCK is false" do
    ENV["USE_MOCK"] = "false"
    adapter = CourtAuctionAdapter.for
    assert_instance_of GovernmentCourtAuctionAdapter, adapter
  ensure
    ENV.delete("USE_MOCK")
  end

  test "mock adapter returns data for known case_number" do
    adapter = MockCourtAuctionAdapter.new
    data = adapter.fetch_data(case_number: "2026타경10001")
    assert data.is_a?(Hash)
    assert data.key?(:remarks)
    assert data.key?(:tenants)
  end

  test "mock adapter returns nil for unknown case_number" do
    adapter = MockCourtAuctionAdapter.new
    data = adapter.fetch_data(case_number: "unknown-999")
    assert_nil data
  end
end
