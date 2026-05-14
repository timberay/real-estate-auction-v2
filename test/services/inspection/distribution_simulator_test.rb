require "test_helper"
require "ostruct"

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
  # ---------------------------------------------------------------------------
  # Sort stability and undated lien handling
  # ---------------------------------------------------------------------------
  test "deterministic dividend assignment when two claimants share a date" do
    tenants = [
      {
        "name" => "A", "deposit" => 30_000_000, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-01-01", "priority_rank" => 1
      },
      {
        "name" => "B", "deposit" => 30_000_000, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-01-01", "priority_rank" => 2
      }
    ]

    run1 = Inspection::DistributionSimulator.call(sale_price: 50_000_000, validated_tenants: tenants, rights_timeline: [])
    run2 = Inspection::DistributionSimulator.call(sale_price: 50_000_000, validated_tenants: tenants, rights_timeline: [])

    assert_equal run1.distributions, run2.distributions
    assert_equal run1.tenant_outcomes, run2.tenant_outcomes
  end

  test "tenant ordered before lien when dates are identical" do
    tenants = [
      {
        "name" => "임차인", "deposit" => 30_000_000, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-01-01", "priority_rank" => 1
      }
    ]
    rights = [
      { "type" => "근저당", "amount" => 100_000_000, "registered_date" => "2024-01-01", "extinguished_on_sale" => true }
    ]

    # Sale 50M − 1.5M = 48.5M. Tenant first (30M), lien gets 18.5M.
    result = Inspection::DistributionSimulator.call(
      sale_price: 50_000_000,
      validated_tenants: tenants,
      rights_timeline: rights
    )
    tenant_outcome = result.tenant_outcomes.first
    assert_equal 30_000_000, tenant_outcome["dividend"]
    assert_equal 0, tenant_outcome["uncovered_remainder"]
  end

  test "undated lien is excluded from waterfall" do
    tenants = [
      {
        "name" => "임차인", "deposit" => 50_000_000, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-06-01", "priority_rank" => 1
      }
    ]
    rights = [
      { "type" => "근저당", "amount" => 100_000_000, "registered_date" => nil, "date" => nil, "extinguished_on_sale" => true }
    ]

    # Without exclusion, the undated lien with sort_date "" would sort before the tenant
    # and consume the proceeds. Tenant should still get its 50M.
    result = Inspection::DistributionSimulator.call(
      sale_price: 100_000_000,
      validated_tenants: tenants,
      rights_timeline: rights
    )
    tenant_outcome = result.tenant_outcomes.first
    assert_equal 50_000_000, tenant_outcome["dividend"]
    assert_equal 0, tenant_outcome["uncovered_remainder"]
    refute(result.distributions.any? { |d| d["kind"] == "lien" })
  end

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

  # ---------------------------------------------------------------------------
  # 최우선변제 (small tenant first-priority) — T1.3 / W1-4 / C25 / E-27
  # ---------------------------------------------------------------------------
  test "first-priority is skipped when property is omitted (existing simulator behavior preserved)" do
    tenants = [
      {
        "name" => "소액", "deposit" => 50_000_000, "move_in_date" => "2024-01-01",
        "confirmed_date" => "2024-01-02", "dividend_requested" => true, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-01-02", "priority_rank" => 1
      }
    ]
    rights = [
      { "type" => "근저당", "amount" => 100_000_000, "registered_date" => "2023-01-01", "extinguished_on_sale" => true }
    ]

    result = Inspection::DistributionSimulator.call(
      sale_price: 100_000_000, validated_tenants: tenants, rights_timeline: rights
    )

    refute(result.distributions.any? { |d| d["kind"] == "first_priority" })
  end

  test "eligible small tenant gets first-priority dividend ahead of an earlier 근저당 (서울 현행)" do
    property = OpenStruct.new(sido: "서울특별시", sigungu: "강남구")
    tenants = [
      {
        "name" => "소액", "deposit" => 50_000_000, "move_in_date" => "2024-01-01",
        "confirmed_date" => "2024-01-02", "dividend_requested" => true, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-01-02", "priority_rank" => 1
      }
    ]
    rights = [
      { "type" => "근저당", "amount" => 200_000_000, "registered_date" => "2023-06-01", "extinguished_on_sale" => true }
    ]

    # Sale 200M − 6M = 194M. First-priority 55M (서울 현행 한도). Tenant 우선변제 capped at deposit−FP = 0.
    # Lien gets 194M − 55M = 139M. Tenant fully repaid, buyer assumes 0.
    result = Inspection::DistributionSimulator.call(
      sale_price: 200_000_000, validated_tenants: tenants, rights_timeline: rights, property: property
    )

    fp_distributions = result.distributions.select { |d| d["kind"] == "first_priority" }
    assert_equal 1, fp_distributions.size
    assert_equal 50_000_000, fp_distributions.first["amount"]  # min(deposit 50M, protection 55M) = 50M

    tenant = result.tenant_outcomes.first
    assert_equal 50_000_000, tenant["dividend"]
    assert_equal 0, tenant["uncovered_remainder"]
    assert_equal 0, result.buyer_assumed_amount
  end

  test "tenant with deposit above 한도 is ineligible for first-priority (but still gets 우선변제 via 확정일자)" do
    property = OpenStruct.new(sido: "서울특별시", sigungu: "강남구")
    tenants = [
      {
        "name" => "고액", "deposit" => 200_000_000, "move_in_date" => "2024-01-01",
        "confirmed_date" => "2024-01-02", "dividend_requested" => true, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-01-02", "priority_rank" => 1
      }
    ]
    rights = []

    # 보증금 2억 > 서울 현행 한도 1억6500만 → first-priority 0. 일반 우선변제 만으로 처리.
    result = Inspection::DistributionSimulator.call(
      sale_price: 250_000_000, validated_tenants: tenants, rights_timeline: rights, property: property
    )

    refute(result.distributions.any? { |d| d["kind"] == "first_priority" })
    tenant = result.tenant_outcomes.first
    # Sale 250M − 7.5M = 242.5M; tenant 200M via 우선변제.
    assert_equal 200_000_000, tenant["dividend"]
  end

  test "tenant without dividend_requested is ineligible for first-priority" do
    property = OpenStruct.new(sido: "서울특별시", sigungu: "강남구")
    tenants = [
      {
        "name" => "미신청", "deposit" => 50_000_000, "move_in_date" => "2024-01-01",
        "confirmed_date" => "2024-01-02", "dividend_requested" => false, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-01-02", "priority_rank" => 1
      }
    ]
    rights = [
      { "type" => "근저당", "amount" => 200_000_000, "registered_date" => "2023-06-01", "extinguished_on_sale" => true }
    ]

    result = Inspection::DistributionSimulator.call(
      sale_price: 100_000_000, validated_tenants: tenants, rights_timeline: rights, property: property
    )

    refute(result.distributions.any? { |d| d["kind"] == "first_priority" })
  end

  test "tenant without move_in_date is ineligible for first-priority (대항요건 미충족)" do
    property = OpenStruct.new(sido: "서울특별시", sigungu: "강남구")
    tenants = [
      {
        "name" => "미전입", "deposit" => 50_000_000, "move_in_date" => nil,
        "confirmed_date" => "2024-01-02", "dividend_requested" => true, "opposing_power" => false,
        "has_priority_repayment" => false, "effective_date" => nil, "priority_rank" => nil
      }
    ]

    result = Inspection::DistributionSimulator.call(
      sale_price: 100_000_000, validated_tenants: tenants, rights_timeline: [], property: property
    )

    refute(result.distributions.any? { |d| d["kind"] == "first_priority" })
  end

  test "aggregate first-priority is capped at 1/2 of sale price and pro-rated when exceeded (시행령 §10③)" do
    property = OpenStruct.new(sido: "서울특별시", sigungu: "강남구")
    tenants = [
      {
        "name" => "A", "deposit" => 50_000_000, "move_in_date" => "2024-01-01",
        "confirmed_date" => "2024-01-02", "dividend_requested" => true, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-01-02", "priority_rank" => 1
      },
      {
        "name" => "B", "deposit" => 50_000_000, "move_in_date" => "2024-01-01",
        "confirmed_date" => "2024-01-02", "dividend_requested" => true, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2024-01-02", "priority_rank" => 2
      }
    ]

    # Sale 80M. Cap = 40M. Each requests min(50M, 55M) = 50M, aggregate 100M. Pro-rate → each 20M.
    result = Inspection::DistributionSimulator.call(
      sale_price: 80_000_000, validated_tenants: tenants, rights_timeline: [], property: property
    )

    fp_distributions = result.distributions.select { |d| d["kind"] == "first_priority" }
    fp_total = fp_distributions.sum { |d| d["amount"] }
    assert_equal 40_000_000, fp_total
    assert(fp_distributions.all? { |d| d["amount"] == 20_000_000 })
  end

  test "period is selected from the earliest extinguishing 근저당 date" do
    property = OpenStruct.new(sido: "서울특별시", sigungu: "강남구")
    tenants = [
      {
        "name" => "오래된", "deposit" => 95_000_000, "move_in_date" => "2014-06-01",
        "confirmed_date" => "2014-06-02", "dividend_requested" => true, "opposing_power" => true,
        "has_priority_repayment" => true, "effective_date" => "2014-06-02", "priority_rank" => 1
      }
    ]
    rights = [
      # Earliest 근저당 falls in 2014-01-01 ~ 2016-03-30 period → 서울 한도 9500만/변제 3200만
      { "type" => "근저당", "amount" => 100_000_000, "registered_date" => "2015-01-01", "extinguished_on_sale" => true },
      { "type" => "근저당", "amount" => 50_000_000, "registered_date" => "2024-01-01", "extinguished_on_sale" => true }
    ]

    result = Inspection::DistributionSimulator.call(
      sale_price: 300_000_000, validated_tenants: tenants, rights_timeline: rights, property: property
    )

    fp_distributions = result.distributions.select { |d| d["kind"] == "first_priority" }
    assert_equal 1, fp_distributions.size
    # Deposit 95M ≤ 한도 95M, protection 32M → tenant gets 32M first-priority.
    assert_equal 32_000_000, fp_distributions.first["amount"]
  end

  test "result exposes small_tenant_period metadata when property is provided" do
    property = OpenStruct.new(sido: "서울특별시", sigungu: "강남구")
    result = Inspection::DistributionSimulator.call(
      sale_price: 100_000_000, validated_tenants: [], rights_timeline: [], property: property
    )
    assert_respond_to result, :small_tenant_period
    refute_nil result.small_tenant_period
    assert_match(/2023-02-21/, result.small_tenant_period[:period_label])
    assert_equal "seoul", result.small_tenant_period[:tier]
  end
end
