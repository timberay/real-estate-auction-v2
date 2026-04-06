require "test_helper"

class RightsAnalysis::OpposingPowerDeterminerTest < ActiveSupport::TestCase
  test "tenant with move-in before base right has opposing power" do
    base_right = { type: "근저당", date: Date.parse("2024-06-01"), holder: "국민은행" }
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-03-01",
          "confirmed_date" => "2024-03-05", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }
    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)
    assert_equal 1, result.size
    assert result.first[:has_opposing_power]
  end

  test "tenant with move-in after base right has no opposing power" do
    base_right = { type: "근저당", date: Date.parse("2024-01-15"), holder: "국민은행" }
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-03-01",
          "confirmed_date" => "2024-03-05", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }
    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)
    assert_equal 1, result.size
    assert_not result.first[:has_opposing_power]
  end

  test "opposing power uses next-day 00:00 rule" do
    base_right = { type: "근저당", date: Date.parse("2024-01-16"), holder: "은행" }
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-01-15",
          "confirmed_date" => "2024-01-16", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }
    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)
    assert result.first[:has_opposing_power]
  end

  test "same-day move-in as base right has no opposing power" do
    base_right = { type: "근저당", date: Date.parse("2024-01-15"), holder: "은행" }
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-01-15",
          "confirmed_date" => "2024-01-16", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }
    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)
    assert_not result.first[:has_opposing_power]
  end

  test "returns empty array when no tenants" do
    base_right = { type: "근저당", date: Date.parse("2024-01-15"), holder: "은행" }
    registry_data = { "tenants" => [] }
    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)
    assert_empty result
  end

  test "returns tenants with all fields preserved" do
    base_right = { type: "근저당", date: Date.parse("2024-01-15"), holder: "은행" }
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-03-01",
          "confirmed_date" => "2024-03-05", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }
    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, base_right)
    tenant = result.first
    assert_equal "임차인A", tenant[:name]
    assert_equal 50_000_000, tenant[:deposit]
    assert_equal "2024-03-01", tenant[:move_in_date]
    assert_equal "2024-03-05", tenant[:confirmed_date]
    assert tenant.key?(:has_opposing_power)
  end

  test "returns all tenants as no-opposing-power when base_right is nil" do
    registry_data = {
      "tenants" => [
        { "name" => "임차인A", "deposit" => 50_000_000, "move_in_date" => "2024-03-01",
          "confirmed_date" => "2024-03-05", "dividend_requested" => true, "is_small_sum_tenant" => false }
      ]
    }
    result = RightsAnalysis::OpposingPowerDeterminer.call(registry_data, nil)
    assert_not result.first[:has_opposing_power]
  end
end
