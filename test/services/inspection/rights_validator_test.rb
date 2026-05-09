require "test_helper"

class Inspection::RightsValidatorTest < ActiveSupport::TestCase
  test "tenant with move_in_date before base_right_date has opposing power" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )
    tenant = result.validated_tenants.first
    assert_equal true, tenant["opposing_power"]
  end

  test "tenant with move_in_date on or after base_right_date has no opposing power" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "박○○", "deposit" => 30_000_000, "move_in_date" => "2024-01-15",
          "confirmed_date" => "2024-01-20", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )
    tenant = result.validated_tenants.first
    assert_equal false, tenant["opposing_power"]
  end

  test "priority repayment is independent of opposing power" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "박○○", "deposit" => 30_000_000, "move_in_date" => "2024-05-01",
          "confirmed_date" => "2024-05-10", "opposing_power" => false, "priority_rank" => 3 }
      ],
      rights_timeline: []
    )
    tenant = result.validated_tenants.first
    assert_equal false, tenant["opposing_power"]
    assert_equal true, tenant["has_priority_repayment"]
  end

  test "no priority repayment when confirmed_date is nil" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "최○○", "deposit" => 20_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => nil, "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )
    tenant = result.validated_tenants.first
    assert_equal true, tenant["opposing_power"]
    assert_equal false, tenant["has_priority_repayment"]
    assert_nil tenant["effective_date"]
    assert_nil tenant["priority_rank"]
  end

  test "effective_date uses max of move_in_date+1 and confirmed_date" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-06-01"),
      tenants: [
        { "name" => "이○○", "deposit" => 40_000_000, "move_in_date" => "2024-01-05",
          "confirmed_date" => "2024-01-01", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )
    tenant = result.validated_tenants.first
    assert_equal "2024-01-06", tenant["effective_date"]
  end

  test "effective_date uses confirmed_date when it is later" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2025-01-01"),
      tenants: [
        { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )
    tenant = result.validated_tenants.first
    assert_equal "2023-06-15", tenant["effective_date"]
  end

  test "priority_rank sorted by effective_date ascending" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2025-01-01"),
      tenants: [
        { "name" => "A", "deposit" => 10_000_000, "move_in_date" => "2024-06-01",
          "confirmed_date" => "2024-06-10", "opposing_power" => true, "priority_rank" => 1 },
        { "name" => "B", "deposit" => 20_000_000, "move_in_date" => "2024-03-01",
          "confirmed_date" => "2024-03-05", "opposing_power" => true, "priority_rank" => 2 }
      ],
      rights_timeline: []
    )
    tenants = result.validated_tenants
    assert_equal "B", tenants.find { |t| t["priority_rank"] == 1 }["name"]
    assert_equal "A", tenants.find { |t| t["priority_rank"] == 2 }["name"]
  end

  test "assumed_amount sums non-extinguished rights" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [],
      rights_timeline: [
        { "date" => "2024-01-15", "type" => "근저당권", "holder" => "○○은행", "amount" => 200_000_000, "extinguished_on_sale" => true },
        { "date" => "2023-01-01", "type" => "전세권", "holder" => "정○○", "amount" => 50_000_000, "extinguished_on_sale" => false }
      ]
    )
    assert_equal 50_000_000, result.validated_amounts["assumed_amount"]
  end

  test "total_risk_amount includes opposing tenant deposits" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: [
        { "date" => "2024-01-15", "type" => "근저당권", "holder" => "○○은행", "amount" => 200_000_000, "extinguished_on_sale" => true }
      ]
    )
    assert_equal 0, result.validated_amounts["assumed_amount"]
    assert_equal 50_000_000, result.validated_amounts["opposing_deposits"]
    assert_equal 50_000_000, result.validated_amounts["total_risk_amount"]
  end

  test "detects discrepancy when LLM and Ruby disagree on opposing_power" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "박○○", "deposit" => 30_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => false, "priority_rank" => 3 }
      ],
      rights_timeline: []
    )
    assert_equal 1, result.discrepancies.size
    d = result.discrepancies.first
    assert_equal "박○○", d["tenant_name"]
    assert_equal "opposing_power", d["field"]
    assert_equal false, d["llm_value"]
    assert_equal true, d["ruby_value"]
  end

  test "no discrepancies when LLM and Ruby agree" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [
        { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )
    assert_empty result.discrepancies
  end

  test "handles empty tenants and rights" do
    result = Inspection::RightsValidator.call(
      base_right_date: Date.parse("2024-01-15"),
      tenants: [],
      rights_timeline: []
    )
    assert_empty result.validated_tenants
    assert_equal 0, result.validated_amounts["assumed_amount"]
    assert_equal 0, result.validated_amounts["opposing_deposits"]
    assert_equal 0, result.validated_amounts["total_risk_amount"]
    assert_empty result.discrepancies
  end

  test "handles nil base_right_date gracefully" do
    result = Inspection::RightsValidator.call(
      base_right_date: nil,
      tenants: [
        { "name" => "김○○", "deposit" => 50_000_000, "move_in_date" => "2023-06-01",
          "confirmed_date" => "2023-06-15", "opposing_power" => true, "priority_rank" => 1 }
      ],
      rights_timeline: []
    )
    tenant = result.validated_tenants.first
    assert_equal false, tenant["opposing_power"]
  end

  test "유치권 is excluded from assumed_amount and surfaced as unevaluated" do
    result = Inspection::RightsValidator.call(
      base_right_date: "2024-01-01",
      tenants: [],
      rights_timeline: [
        { "right_type" => "근저당", "amount" => 100_000_000, "extinguished_on_sale" => true },
        { "right_type" => "유치권", "amount" => 50_000_000, "extinguished_on_sale" => false }
      ]
    )
    assert_equal 0, result.validated_amounts["assumed_amount"]
    assert_equal 1, result.validated_amounts["unevaluated_rights"].size
    assert_equal "유치권", result.validated_amounts["unevaluated_rights"].first["right_type"]
    assert_match(/별도 평가 필요/, result.validated_amounts["disclaimer"])
  end

  test "선순위 가등기 (extinguished_on_sale=false) is unevaluated" do
    result = Inspection::RightsValidator.call(
      base_right_date: "2024-01-01",
      tenants: [],
      rights_timeline: [
        { "right_type" => "가등기", "amount" => 0, "extinguished_on_sale" => false }
      ]
    )
    assert_equal 0, result.validated_amounts["assumed_amount"]
    assert_equal 1, result.validated_amounts["unevaluated_rights"].size
  end

  test "summable rights still aggregate correctly when no unevaluated" do
    result = Inspection::RightsValidator.call(
      base_right_date: "2024-01-01",
      tenants: [],
      rights_timeline: [
        { "right_type" => "가압류", "amount" => 30_000_000, "extinguished_on_sale" => false }
      ]
    )
    assert_equal 30_000_000, result.validated_amounts["assumed_amount"]
    assert_empty result.validated_amounts["unevaluated_rights"]
    assert_nil result.validated_amounts["disclaimer"]
  end

  test "right_type with whitespace matches UNEVALUATED_TYPES" do
    result = Inspection::RightsValidator.call(
      base_right_date: "2024-01-01",
      tenants: [],
      rights_timeline: [
        { "right_type" => "선순위 세금압류", "amount" => 10_000_000, "extinguished_on_sale" => false }
      ]
    )
    assert_equal 0, result.validated_amounts["assumed_amount"]
    assert_equal 1, result.validated_amounts["unevaluated_rights"].size
  end
end
