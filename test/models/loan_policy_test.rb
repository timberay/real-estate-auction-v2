require "test_helper"

class LoanPolicyTest < ActiveSupport::TestCase
  test "valid with all required fields" do
    lp = LoanPolicy.new(
      property_type: property_types(:apartment),
      policy_name: "경락대출 (1금융)", loan_ratio: 0.7, regulated_loan_ratio: 0.4,
      effective_date: Date.new(2026, 1, 1), enabled: true
    )
    assert lp.valid?
  end

  test "invalid without policy_name" do
    lp = LoanPolicy.new(
      property_type: property_types(:apartment), policy_name: nil,
      loan_ratio: 0.7, regulated_loan_ratio: 0.4,
      effective_date: Date.new(2026, 1, 1)
    )
    assert_not lp.valid?
  end

  test "invalid with loan_ratio outside 0-1 range" do
    lp = LoanPolicy.new(
      property_type: property_types(:apartment), policy_name: "테스트",
      loan_ratio: 1.5, regulated_loan_ratio: 0.4,
      effective_date: Date.new(2026, 1, 1)
    )
    assert_not lp.valid?
    assert_includes lp.errors[:loan_ratio], "must be less than or equal to 1"
  end

  test "invalid without regulated_loan_ratio" do
    lp = LoanPolicy.new(
      property_type: property_types(:apartment), policy_name: "테스트",
      loan_ratio: 0.7, regulated_loan_ratio: nil,
      effective_date: Date.new(2026, 1, 1)
    )
    assert_not lp.valid?
    assert_includes lp.errors[:regulated_loan_ratio], "can't be blank"
  end

  test "invalid with regulated_loan_ratio outside 0-1 range" do
    lp = LoanPolicy.new(
      property_type: property_types(:apartment), policy_name: "테스트",
      loan_ratio: 0.7, regulated_loan_ratio: 1.5,
      effective_date: Date.new(2026, 1, 1)
    )
    assert_not lp.valid?
    assert_includes lp.errors[:regulated_loan_ratio], "must be less than or equal to 1"
  end

  test "ratio_for(region) returns regulated ratio for Seoul, non-regulated otherwise" do
    lp = LoanPolicy.new(loan_ratio: 0.7, regulated_loan_ratio: 0.4)
    assert_equal 0.4, lp.ratio_for("서울특별시").to_f
    assert_equal 0.7, lp.ratio_for("경기도").to_f
    assert_equal 0.7, lp.ratio_for(nil).to_f
  end

  test "scope active returns enabled policies without expiry or future expiry" do
    apt = property_types(:apartment)
    active = LoanPolicy.create!(
      property_type: apt, policy_name: "Active",
      loan_ratio: 0.7, regulated_loan_ratio: 0.4,
      effective_date: Date.new(2026, 1, 1),
      expiry_date: nil, enabled: true
    )
    expired = LoanPolicy.create!(
      property_type: apt, policy_name: "Expired",
      loan_ratio: 0.6, regulated_loan_ratio: 0.4,
      effective_date: Date.new(2025, 1, 1),
      expiry_date: Date.new(2025, 12, 31), enabled: true
    )
    disabled = LoanPolicy.create!(
      property_type: apt, policy_name: "Disabled",
      loan_ratio: 0.8, regulated_loan_ratio: 0.4,
      effective_date: Date.new(2026, 1, 1),
      expiry_date: nil, enabled: false
    )
    results = LoanPolicy.active
    assert_includes results, active
    assert_not_includes results, expired
    assert_not_includes results, disabled
  end

  test "scope for_property_type filters by property type" do
    BudgetSetting.delete_all
    LoanPolicy.delete_all
    apt = property_types(:apartment)
    villa = property_types(:villa)
    LoanPolicy.create!(
      property_type: apt, policy_name: "아파트용",
      loan_ratio: 0.7, regulated_loan_ratio: 0.4,
      effective_date: Date.new(2026, 1, 1), enabled: true
    )
    LoanPolicy.create!(
      property_type: villa, policy_name: "빌라용",
      loan_ratio: 0.6, regulated_loan_ratio: 0.4,
      effective_date: Date.new(2026, 1, 1), enabled: true
    )
    results = LoanPolicy.for_property_type(apt.id)
    assert_equal 1, results.count
    assert_equal "아파트용", results.first.policy_name
  end
end
