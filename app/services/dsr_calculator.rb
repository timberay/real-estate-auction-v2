class DsrCalculator
  # 한국 차주규제 표준 (일반 차주). 청년/신혼/농촌 등 50% 적용 케이스는
  # 향후 별도 분기로 확장.
  DEFAULT_THRESHOLD = 0.40

  # 한국 시중은행 부동산담보대출 평균 금리 (2026 기준 가정).
  # 실제 금리는 LoanPolicy 에 들어 있지 않으므로 보수적 가정값 사용.
  DEFAULT_ANNUAL_RATE = 0.045

  # 표준 만기 30년 원리금균등상환.
  DEFAULT_TERM_YEARS = 30

  Result = Data.define(:dsr_ratio, :monthly_payment_manwon, :annual_debt_service_manwon, :threshold) do
    def breached?
      dsr_ratio > threshold
    end
  end

  def self.call(**kwargs) = new(**kwargs).call

  def initialize(annual_income_manwon:, existing_debt_monthly_manwon: 0,
                 new_loan_principal_manwon:,
                 annual_rate: DEFAULT_ANNUAL_RATE, term_years: DEFAULT_TERM_YEARS,
                 threshold: DEFAULT_THRESHOLD)
    raise ArgumentError, "annual_income must be positive" if annual_income_manwon.to_i <= 0

    @annual_income = annual_income_manwon.to_d
    @existing_debt_monthly = existing_debt_monthly_manwon.to_d
    @new_loan_principal = new_loan_principal_manwon.to_d
    @annual_rate = annual_rate.to_d
    @term_years = term_years.to_i
    @threshold = threshold.to_f
  end

  def call
    monthly_payment = compute_monthly_payment
    annual_debt = (monthly_payment + @existing_debt_monthly) * 12
    ratio = (annual_debt / @annual_income).to_f

    Result.new(
      dsr_ratio: ratio,
      monthly_payment_manwon: monthly_payment.round,
      annual_debt_service_manwon: annual_debt.round,
      threshold: @threshold
    )
  end

  private

  # 원리금균등상환 월 납입액. 무이자(0%)일 땐 단순 분할 상환.
  def compute_monthly_payment
    return 0 if @new_loan_principal.zero?
    return @new_loan_principal / months if @annual_rate.zero?

    r = @annual_rate / 12
    n = months
    pow = (1 + r)**n
    @new_loan_principal * (r * pow) / (pow - 1)
  end

  def months
    @term_years * 12
  end
end
