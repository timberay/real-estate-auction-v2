require "test_helper"

class RightsAnalysis::OpportunityDetectorTest < ActiveSupport::TestCase
  test "detects HUG waiver opportunity" do
    registry_data = { "hug_waiver" => true }
    tenants = [ { name: "임차인A", deposit: 50_000_000, has_opposing_power: true } ]
    result = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: tenants, check_results: []
    )
    assert_equal "hug_waiver", result[:opportunity_type]
    assert_includes result[:opportunity_reason], "HUG"
  end

  test "detects full-dividend opportunity" do
    registry_data = { "hug_waiver" => false }
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: true, confirmed_date: "2024-03-05", estimated_dividend: 50_000_000 }
    ]
    result = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: tenants, check_results: []
    )
    assert_equal "full_dividend", result[:opportunity_type]
    assert_includes result[:opportunity_reason], "배당"
  end

  test "returns nil when no opportunity" do
    registry_data = { "hug_waiver" => false }
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: false, confirmed_date: nil }
    ]
    result = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: tenants, check_results: []
    )
    assert_nil result[:opportunity_type]
  end

  test "returns nil when no tenants and no HUG" do
    registry_data = { "hug_waiver" => false }
    result = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: [], check_results: []
    )
    assert_nil result[:opportunity_type]
  end

  test "HUG waiver takes priority over full-dividend" do
    registry_data = { "hug_waiver" => true }
    tenants = [
      { name: "임차인A", deposit: 50_000_000, has_opposing_power: true,
        dividend_requested: true, confirmed_date: "2024-03-05", estimated_dividend: 50_000_000 }
    ]
    result = RightsAnalysis::OpportunityDetector.call(
      registry_data: registry_data, tenants: tenants, check_results: []
    )
    assert_equal "hug_waiver", result[:opportunity_type]
  end
end
