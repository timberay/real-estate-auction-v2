require "test_helper"

class RightsAnalysis::DividendSimulatorTest < ActiveSupport::TestCase
  test "distributes to auction costs first" do
    rights = [ { "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 } ]
    tenants = []
    seizures = []
    result = RightsAnalysis::DividendSimulator.call(
      rights: rights, tenants: tenants, seizures: seizures,
      expected_bid: 150_000_000, auction_cost: 3_000_000
    )
    costs_row = result[:distribution].find { |d| d[:type] == "경매 비용" }
    assert_equal 3_000_000, costs_row[:dividend]
  end

  test "mortgage receives remainder after costs" do
    rights = [ { "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 } ]
    result = RightsAnalysis::DividendSimulator.call(
      rights: rights, tenants: [], seizures: [],
      expected_bid: 150_000_000, auction_cost: 3_000_000
    )
    mortgage_row = result[:distribution].find { |d| d[:holder] == "국민은행" }
    assert_equal 147_000_000, mortgage_row[:dividend]
    assert_equal 53_000_000, mortgage_row[:shortfall]
  end

  test "small sum tenant gets priority repayment" do
    rights = [ { "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 } ]
    tenants = [
      { name: "소액임차인", deposit: 16_500_000, has_opposing_power: true,
        dividend_requested: true, confirmed_date: "2024-03-05", is_small_sum_tenant: true }
    ]
    result = RightsAnalysis::DividendSimulator.call(
      rights: rights, tenants: tenants, seizures: [],
      expected_bid: 150_000_000, auction_cost: 3_000_000
    )
    small_sum_row = result[:distribution].find { |d| d[:holder] == "소액임차인" }
    assert_equal 16_500_000, small_sum_row[:dividend]
  end

  test "bidder burden shows safe when no assumed amount" do
    rights = [ { "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 100_000_000 } ]
    result = RightsAnalysis::DividendSimulator.call(
      rights: rights, tenants: [], seizures: [],
      expected_bid: 150_000_000, auction_cost: 3_000_000
    )
    assert_equal 0, result[:bidder_burden][:assumed_amount]
    assert_equal "safe", result[:bidder_burden][:verdict]
  end

  test "bidder burden shows danger when assumed amount exists" do
    rights = [ { "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 100_000_000 } ]
    tenants = [
      { name: "임차인A", deposit: 30_000_000, has_opposing_power: true,
        dividend_requested: false, confirmed_date: nil, is_small_sum_tenant: false }
    ]
    result = RightsAnalysis::DividendSimulator.call(
      rights: rights, tenants: tenants, seizures: [],
      expected_bid: 150_000_000, auction_cost: 3_000_000
    )
    assert_equal 30_000_000, result[:bidder_burden][:assumed_amount]
    assert_equal "danger", result[:bidder_burden][:verdict]
  end

  test "returns nil distribution when expected_bid is nil" do
    result = RightsAnalysis::DividendSimulator.call(
      rights: [], tenants: [], seizures: [],
      expected_bid: nil, auction_cost: 3_000_000
    )
    assert_empty result[:distribution]
    assert_nil result[:expected_bid]
  end
end
