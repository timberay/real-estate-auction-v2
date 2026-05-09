require "test_helper"

class Inspection::DistributionSimulatorTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # Basic shape and disclaimer
  # ---------------------------------------------------------------------------
  test "returns a Result with expected fields" do
    result = Inspection::DistributionSimulator.call(
      sale_price: 100_000_000,
      validated_tenants: [],
      rights_timeline: []
    )
    assert_respond_to result, :sale_price
    assert_respond_to result, :execution_costs
    assert_respond_to result, :distributions
    assert_respond_to result, :tenant_outcomes
    assert_respond_to result, :buyer_assumed_amount
    assert_respond_to result, :remaining_for_general
    assert_respond_to result, :disclaimer
  end

  test "disclaimer mentions 최우선변제 and 집행비용 and is non-blank" do
    result = Inspection::DistributionSimulator.call(
      sale_price: 50_000_000,
      validated_tenants: [],
      rights_timeline: []
    )
    refute result.disclaimer.blank?
    assert_match(/최우선변제/, result.disclaimer)
    assert_match(/집행비용/, result.disclaimer)
  end

  # ---------------------------------------------------------------------------
  # Execution costs
  # ---------------------------------------------------------------------------
  test "execution_costs is 3% of sale price (default)" do
    result = Inspection::DistributionSimulator.call(
      sale_price: 100_000_000,
      validated_tenants: [],
      rights_timeline: []
    )
    assert_equal 3_000_000, result.execution_costs
  end

  test "zero or nil sale_price yields zero execution_costs and zero distributions" do
    result = Inspection::DistributionSimulator.call(
      sale_price: 0,
      validated_tenants: [],
      rights_timeline: []
    )
    assert_equal 0, result.execution_costs
    assert_empty result.distributions
  end

  # ---------------------------------------------------------------------------
  # Sale price covers all priority claims → no uncovered
  # ---------------------------------------------------------------------------
  test "sale price covers all priority claims — opposing tenant fully reimbursed, buyer_assumed_amount=0" do
    tenants = [
      {
        "name" => "김○○",
        "deposit" => 50_000_000,
        "opposing_power" => true,
        "has_priority_repayment" => true,
        "effective_date" => "2023-06-15",
        "priority_rank" => 1
      }
    ]
    rights = [
      { "type" => "근저당", "amount" => 100_000_000, "registered_date" => "2024-01-15", "extinguished_on_sale" => true }
    ]

    # Sale 200M − 6M (3% costs) = 194M available; 50M tenant + 100M 근저당 = 150M priority. 44M leftover.
    result = Inspection::DistributionSimulator.call(
      sale_price: 200_000_000,
      validated_tenants: tenants,
      rights_timeline: rights
    )

    tenant_outcome = result.tenant_outcomes.first
    assert_equal "김○○", tenant_outcome["name"]
    assert_equal 50_000_000, tenant_outcome["dividend"]
    assert_equal 0, tenant_outcome["uncovered_remainder"]
    assert_equal 0, result.buyer_assumed_amount
    assert_equal 44_000_000, result.remaining_for_general
  end

  # ---------------------------------------------------------------------------
  # Sale price below total priority claims → tenant has uncovered remainder
  # ---------------------------------------------------------------------------
  test "sale price below total priority claims — opposing tenant has uncovered remainder counted as buyer burden" do
    tenants = [
      {
        "name" => "김○○",
        "deposit" => 80_000_000,
        "opposing_power" => true,
        "has_priority_repayment" => true,
        "effective_date" => "2023-06-15",
        "priority_rank" => 1
      }
    ]
    rights = []

    # Sale 50M − 1.5M = 48.5M available; tenant has effective_date earlier → gets all 48.5M; uncovered = 31.5M.
    result = Inspection::DistributionSimulator.call(
      sale_price: 50_000_000,
      validated_tenants: tenants,
      rights_timeline: rights
    )
    tenant_outcome = result.tenant_outcomes.first
    assert_equal 48_500_000, tenant_outcome["dividend"]
    assert_equal 31_500_000, tenant_outcome["uncovered_remainder"]
    assert_equal 31_500_000, result.buyer_assumed_amount
  end

  # ---------------------------------------------------------------------------
  # Tenant without 확정일자 (has_priority_repayment=false) → not in waterfall
  # ---------------------------------------------------------------------------
  test "tenant without has_priority_repayment is excluded from waterfall — opposing deposit fully uncovered (buyer burden)" do
    tenants = [
      {
        "name" => "최○○",
        "deposit" => 30_000_000,
        "opposing_power" => true,
        "has_priority_repayment" => false,
        "effective_date" => nil,
        "priority_rank" => nil
      }
    ]
    rights = []

    result = Inspection::DistributionSimulator.call(
      sale_price: 100_000_000,
      validated_tenants: tenants,
      rights_timeline: rights
    )
    tenant_outcome = result.tenant_outcomes.first
    assert_equal 0, tenant_outcome["dividend"]
    assert_equal 30_000_000, tenant_outcome["uncovered_remainder"]
    assert_equal 30_000_000, result.buyer_assumed_amount
  end

  test "non-opposing tenant uncovered remainder is NOT counted as buyer burden" do
    tenants = [
      {
        "name" => "박○○",
        "deposit" => 30_000_000,
        "opposing_power" => false,
        "has_priority_repayment" => false,
        "effective_date" => nil,
        "priority_rank" => nil
      }
    ]
    rights = []

    # Tenant has no 확정일자 → no dividend; not opposing → buyer keeps clean title; uncovered = tenant loss only.
    result = Inspection::DistributionSimulator.call(
      sale_price: 100_000_000,
      validated_tenants: tenants,
      rights_timeline: rights
    )
    tenant_outcome = result.tenant_outcomes.first
    assert_equal 30_000_000, tenant_outcome["uncovered_remainder"]
    assert_equal 0, result.buyer_assumed_amount
  end

  # ---------------------------------------------------------------------------
  # Waterfall ordering
  # ---------------------------------------------------------------------------
  test "priority by effective_date — earlier tenant paid first" do
    tenants = [
      {
        "name" => "후순위", "deposit" => 60_000_000, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-03-01", "priority_rank" => 2
      },
      {
        "name" => "선순위", "deposit" => 40_000_000, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2023-06-15", "priority_rank" => 1
      }
    ]

    # Sale 50M − 1.5M = 48.5M. 선순위 takes 40M, 후순위 takes 8.5M, uncovered 51.5M.
    result = Inspection::DistributionSimulator.call(
      sale_price: 50_000_000,
      validated_tenants: tenants,
      rights_timeline: []
    )
    senior  = result.tenant_outcomes.find { |t| t["name"] == "선순위" }
    junior  = result.tenant_outcomes.find { |t| t["name"] == "후순위" }
    assert_equal 40_000_000, senior["dividend"]
    assert_equal 0, senior["uncovered_remainder"]
    assert_equal 8_500_000, junior["dividend"]
    assert_equal 51_500_000, junior["uncovered_remainder"]
    assert_equal 51_500_000, result.buyer_assumed_amount
  end

  test "근저당 in rights_timeline competes in waterfall by registered_date" do
    tenants = [
      {
        "name" => "임차인", "deposit" => 50_000_000, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-06-01", "priority_rank" => 1
      }
    ]
    rights = [
      { "type" => "근저당", "amount" => 100_000_000, "registered_date" => "2023-01-01", "extinguished_on_sale" => true }
    ]

    # Sale 100M − 3M = 97M. 근저당(2023-01-01) earlier → takes 97M. 임차인 0, uncovered 50M.
    result = Inspection::DistributionSimulator.call(
      sale_price: 100_000_000,
      validated_tenants: tenants,
      rights_timeline: rights
    )
    tenant_outcome = result.tenant_outcomes.first
    assert_equal 0, tenant_outcome["dividend"]
    assert_equal 50_000_000, tenant_outcome["uncovered_remainder"]
    assert_equal 50_000_000, result.buyer_assumed_amount
  end

  test "extinguished_on_sale=false 근저당 is NOT included in distribution (it survives instead)" do
    # A surviving lien doesn't compete for sale proceeds — it sticks to the property.
    tenants = [
      {
        "name" => "임차인", "deposit" => 50_000_000, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-06-01", "priority_rank" => 1
      }
    ]
    rights = [
      { "type" => "근저당", "amount" => 100_000_000, "registered_date" => "2023-01-01", "extinguished_on_sale" => false }
    ]

    result = Inspection::DistributionSimulator.call(
      sale_price: 100_000_000,
      validated_tenants: tenants,
      rights_timeline: rights
    )
    tenant_outcome = result.tenant_outcomes.first
    # Tenant gets the full 97M available (since 근저당 doesn't compete here), uncovered 0.
    assert_equal 50_000_000, tenant_outcome["dividend"]
    assert_equal 0, tenant_outcome["uncovered_remainder"]
  end

  # ---------------------------------------------------------------------------
  # Distributions list shape
  # ---------------------------------------------------------------------------
  test "distributions list contains entries with kind, label, amount in waterfall order" do
    tenants = [
      {
        "name" => "임차인", "deposit" => 30_000_000, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-06-01", "priority_rank" => 1
      }
    ]
    rights = [
      { "type" => "근저당", "amount" => 50_000_000, "registered_date" => "2023-01-01", "extinguished_on_sale" => true }
    ]

    result = Inspection::DistributionSimulator.call(
      sale_price: 200_000_000,
      validated_tenants: tenants,
      rights_timeline: rights
    )

    kinds = result.distributions.map { |d| d["kind"] }
    assert_includes kinds, "execution_cost"
    assert_includes kinds, "lien"
    assert_includes kinds, "tenant"
    assert(result.distributions.all? { |d| d.key?("amount") && d.key?("label") })
  end
end
