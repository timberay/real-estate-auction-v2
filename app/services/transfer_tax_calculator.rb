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
                 holding_period:, regulated_region:)
    @taxable_gain_manwon = taxable_gain_manwon.to_i
    @property_type_id = property_type_id
    @household_tier = household_tier
    @holding_period = holding_period
    @regulated_region = regulated_region
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

  def lookup_row
    TransferTaxRate
      .where(property_type_id: @property_type_id,
             household_tier: @household_tier,
             holding_period: @holding_period)
      .where("regulated_region IS NULL OR regulated_region = ?", @regulated_region)
      .order(Arel.sql("(regulated_region IS NULL)"))
      .first
  end

  def lookup_signature
    "property_type=#{@property_type_id}, tier=#{@household_tier}, " \
      "holding=#{@holding_period}, regulated=#{@regulated_region}, " \
      "gain=#{@taxable_gain_manwon}"
  end
end
