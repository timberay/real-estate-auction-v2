class TransferTaxCalculator
  class RateNotFoundError < StandardError; end

  Result = Data.define(:rate, :tax_manwon, :rate_source)

  def self.call(**kwargs) = new(**kwargs).call

  # JSON-friendly nested hash for client-side lookup.
  # Returns: { "homeless" => { "under_1y" => 0.70, ... }, ... }
  def self.matrix_for(property_type_id:, regulated_region:)
    rows = TransferTaxRate
      .where(property_type_id: property_type_id)
      .where("regulated_region IS NULL OR regulated_region = ?", regulated_region)
      .order(Arel.sql("(regulated_region IS NULL)"))

    matrix = Hash.new { |h, k| h[k] = {} }
    rows.each do |row|
      # Concrete (non-NULL) match wins over the NULL wildcard for the same
      # (tier, period) cell because of the ORDER BY above.
      matrix[row.household_tier][row.holding_period] ||= row.total_rate.to_d
    end
    matrix
  end

  def initialize(taxable_gain_manwon:, property_type_id:, household_tier:,
                 holding_period:, regulated_region:, residency_met: true)
    @taxable_gain_manwon = taxable_gain_manwon.to_i
    @property_type_id = property_type_id
    @household_tier = household_tier
    @holding_period = holding_period
    @regulated_region = regulated_region
    @residency_met = residency_met
  end

  def call
    row = lookup_row
    raise RateNotFoundError, lookup_signature if row.nil?

    rate = row.total_rate.to_d
    tax = (rate * @taxable_gain_manwon).round
    tax = 0 if tax.negative?

    Rails.logger.info(
      "TransferTaxCalculator rate=#{rate} src_id=#{row.id} #{lookup_signature}"
    )

    Result.new(rate: rate, tax_manwon: tax, rate_source: row)
  end

  private

  # T1.2-F-B — 1세대 1주택 비과세는 보유 2년 + 거주 2년 요건이 필요하다.
  # 거주 요건이 충족되지 않은 1주택 over_2y 양도는 비과세 대상이 아니므로
  # 무주택 행 (일반 6% 등) 으로 폴백하여 보수적으로 추정한다. 12억 초과
  # 부분에 대한 누진 정밀 계산은 별도 (UI 경고로 안내).
  def effective_household_tier
    return @household_tier unless @household_tier == "single_home" &&
                                  @holding_period == "over_2y" &&
                                  @residency_met == false
    "homeless"
  end

  def lookup_row
    TransferTaxRate
      .where(property_type_id: @property_type_id,
             household_tier: effective_household_tier,
             holding_period: @holding_period)
      .where("regulated_region IS NULL OR regulated_region = ?", @regulated_region)
      .order(Arel.sql("(regulated_region IS NULL)"))
      .first
  end

  def lookup_signature
    "property_type=#{@property_type_id}, tier=#{@household_tier}" \
      "#{@household_tier == effective_household_tier ? '' : "(eff=#{effective_household_tier})"}, " \
      "holding=#{@holding_period}, regulated=#{@regulated_region}, " \
      "residency_met=#{@residency_met}, gain=#{@taxable_gain_manwon}"
  end
end
