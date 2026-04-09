require "test_helper"

class AdapterFactoryTest < ActiveSupport::TestCase
  test "CourtAuctionAdapter.for returns mock by default" do
    adapter = CourtAuctionAdapter.for
    assert_instance_of MockCourtAuctionAdapter, adapter
  end

  test "CourtAuctionAdapter.for returns mock with empty config" do
    adapter = CourtAuctionAdapter.for({})
    assert_instance_of MockCourtAuctionAdapter, adapter
  end

  test "CourtAuctionAdapter.for returns real with real config" do
    adapter = CourtAuctionAdapter.for(adapter: :real)
    assert_instance_of GovernmentCourtAuctionAdapter, adapter
  end

  test "BuildingLedgerAdapter.for returns real with api_key" do
    adapter = BuildingLedgerAdapter.for(adapter: :real, api_key: "test-key")
    assert_instance_of GovernmentBuildingLedgerAdapter, adapter
  end

  test "RegistryTranscriptAdapter.for returns mock by default" do
    adapter = RegistryTranscriptAdapter.for
    assert_instance_of MockRegistryTranscriptAdapter, adapter
  end

  test "LoanPolicyAdapter.for returns mock by default" do
    adapter = LoanPolicyAdapter.for
    assert_instance_of MockLoanPolicyAdapter, adapter
  end
end
