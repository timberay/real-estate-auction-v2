require "test_helper"

class MockRegistryTranscriptAdapterTest < ActiveSupport::TestCase
  setup do
    @adapter = MockRegistryTranscriptAdapter.new
  end

  test "returns predefined data for known case numbers" do
    data = @adapter.fetch_data(case_number: "2026타경10001")
    assert_not_nil data
    assert data.key?(:rights)
    assert data.key?(:tenants)
    assert data.key?(:hug_waiver)
    assert data.key?(:seizures)
  end

  test "generates deterministic random data for unknown case numbers" do
    data1 = @adapter.fetch_data(case_number: "2099타경99999")
    data2 = @adapter.fetch_data(case_number: "2099타경99999")
    assert_equal data1, data2
  end

  test "different case numbers produce different data" do
    data1 = @adapter.fetch_data(case_number: "2099타경11111")
    data2 = @adapter.fetch_data(case_number: "2099타경22222")
    assert_not_equal data1[:rights].first[:holder], data2[:rights].first[:holder]
  end

  test "generated rights have required fields" do
    data = @adapter.fetch_data(case_number: "2099타경99999")
    right = data[:rights].first
    assert right.key?(:type)
    assert right.key?(:date)
    assert right.key?(:holder)
    assert right.key?(:amount)
    assert right.key?(:status)
    assert right.key?(:registry_section)
  end

  test "generated tenants have required fields" do
    data = nil
    (1..20).each do |i|
      data = @adapter.fetch_data(case_number: "2099타경#{10000 + i}")
      break if data[:tenants].any?
    end
    return if data[:tenants].empty?

    tenant = data[:tenants].first
    assert tenant.key?(:name)
    assert tenant.key?(:deposit)
    assert tenant.key?(:move_in_date)
    assert tenant.key?(:confirmed_date)
    assert tenant.key?(:dividend_requested)
    assert tenant.key?(:is_small_sum_tenant)
  end

  test "factory method returns mock adapter when USE_MOCK is not false" do
    adapter = RegistryTranscriptAdapter.for
    assert_kind_of MockRegistryTranscriptAdapter, adapter
  end

  test "risky villa has tenants and rights" do
    data = @adapter.fetch_data(case_number: "2026타경10002")
    assert data[:rights].any?
    assert data[:tenants].any?
  end
end
