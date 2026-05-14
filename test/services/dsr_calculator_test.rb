require "test_helper"

class DsrCalculatorTest < ActiveSupport::TestCase
  # Reference scenario:
  # 연봉 6,000만원, 기존 부채 월 0원, 신규 대출 3억원, 4.5% 30년 원리금균등
  # 월 원리금 = 300,000,000 × (0.00375 × 1.00375^360) / (1.00375^360 − 1)
  #        ≈ 1,520,083원
  # 연 원리금 = 18,241,000원 (대략)
  # DSR = 18,241,000 / 60,000,000 ≈ 0.304 → 30.4%
  test "computes DSR for typical scenario" do
    result = DsrCalculator.call(
      annual_income_manwon: 6000,
      existing_debt_monthly_manwon: 0,
      new_loan_principal_manwon: 30000, # 3억
      annual_rate: 0.045,
      term_years: 30
    )
    assert_in_delta 0.304, result.dsr_ratio, 0.005
    assert_in_delta 152, result.monthly_payment_manwon, 1
    assert_equal false, result.breached?
    assert_equal 0.40, result.threshold
  end

  test "marks breached when DSR exceeds 40%" do
    # 같은 시나리오에서 신규 대출을 5억으로 키우면 DSR ~50%
    result = DsrCalculator.call(
      annual_income_manwon: 6000,
      existing_debt_monthly_manwon: 0,
      new_loan_principal_manwon: 50000,
      annual_rate: 0.045,
      term_years: 30
    )
    assert result.dsr_ratio > 0.40
    assert result.breached?
  end

  test "includes existing_debt_monthly in the ratio" do
    base = DsrCalculator.call(
      annual_income_manwon: 6000,
      existing_debt_monthly_manwon: 0,
      new_loan_principal_manwon: 30000,
      annual_rate: 0.045,
      term_years: 30
    )
    with_existing = DsrCalculator.call(
      annual_income_manwon: 6000,
      existing_debt_monthly_manwon: 100, # 월 100만원 추가
      new_loan_principal_manwon: 30000,
      annual_rate: 0.045,
      term_years: 30
    )
    # 추가 100만원 × 12 = 1,200만원/연 → DSR 추가 +20%p
    assert_in_delta base.dsr_ratio + 0.20, with_existing.dsr_ratio, 0.001
  end

  test "returns dsr_ratio = 0 when new_loan_principal is zero and no existing debt" do
    result = DsrCalculator.call(
      annual_income_manwon: 6000,
      existing_debt_monthly_manwon: 0,
      new_loan_principal_manwon: 0,
      annual_rate: 0.045,
      term_years: 30
    )
    assert_equal 0.0, result.dsr_ratio
    assert_equal 0, result.monthly_payment_manwon
    assert_equal false, result.breached?
  end

  test "raises ArgumentError when annual_income is zero or negative" do
    assert_raises(ArgumentError) do
      DsrCalculator.call(
        annual_income_manwon: 0,
        existing_debt_monthly_manwon: 0,
        new_loan_principal_manwon: 30000,
        annual_rate: 0.045,
        term_years: 30
      )
    end
  end

  test "default annual_rate is 0.045 and term_years is 30" do
    explicit = DsrCalculator.call(
      annual_income_manwon: 6000,
      existing_debt_monthly_manwon: 0,
      new_loan_principal_manwon: 30000,
      annual_rate: 0.045,
      term_years: 30
    )
    default = DsrCalculator.call(
      annual_income_manwon: 6000,
      existing_debt_monthly_manwon: 0,
      new_loan_principal_manwon: 30000
    )
    assert_in_delta explicit.dsr_ratio, default.dsr_ratio, 1e-6
  end

  test "DEFAULT_THRESHOLD = 0.40 mirrors Korean 차주규제 standard" do
    assert_equal 0.40, DsrCalculator::DEFAULT_THRESHOLD
  end

  test "interest-only edge: annual_rate = 0 uses simple division (no compound)" do
    # 30년 5억, 무이자 → 월 5억/360 ≈ 1,388,889원
    result = DsrCalculator.call(
      annual_income_manwon: 6000,
      existing_debt_monthly_manwon: 0,
      new_loan_principal_manwon: 50000,
      annual_rate: 0.0,
      term_years: 30
    )
    assert_in_delta 138.89, result.monthly_payment_manwon, 0.5
  end
end
