class AcquisitionTaxCalculator
  class RateNotFoundError < StandardError; end

  Result = Data.define(:rate, :tax_manwon, :rate_source)

  def self.call(**kwargs) = new(**kwargs).call

  def self.brackets_for(property_type_id:, household_tier:,
                        regulated_region:, area_over_85:)
    scope = AcquisitionTaxRate
      .where(property_type_id: property_type_id, household_tier: household_tier)
      .where("regulated_region IS NULL OR regulated_region = ?", regulated_region)
      .where("area_over_85 IS NULL OR area_over_85 = ?", area_over_85)
      .order(:price_bucket_min_manwon)

    scope.map do |row|
      { rate: row.total_rate.to_d, max: row.price_bucket_max_manwon }
    end
  end

  def initialize(bid_manwon:, property_type_id:, household_tier:,
                 regulated_region:, area_over_85: nil)
    @bid_manwon = bid_manwon.to_i
    @property_type_id = property_type_id
    @household_tier = household_tier
    @regulated_region = regulated_region
    @area_over_85 = area_over_85
  end

  def call
    row = lookup_row
    raise RateNotFoundError, lookup_signature if row.nil?

    rate = row.total_rate.to_d
    Result.new(rate: rate, tax_manwon: (rate * @bid_manwon).round, rate_source: row)
  end

  private

  def lookup_row
    scope = AcquisitionTaxRate
      .where(property_type_id: @property_type_id, household_tier: @household_tier)
      .where("price_bucket_min_manwon <= ?", @bid_manwon)
      .where("price_bucket_max_manwon IS NULL OR price_bucket_max_manwon > ?", @bid_manwon)

    scope = scope.where("regulated_region IS NULL OR regulated_region = ?", @regulated_region)
    scope = scope.where("area_over_85 IS NULL OR area_over_85 = ?", @area_over_85)

    # Prefer concrete matches over NULL (wildcard) ones.
    scope
      .order(Arel.sql("(regulated_region IS NULL), (area_over_85 IS NULL)"))
      .first
  end

  def lookup_signature
    "property_type=#{@property_type_id}, tier=#{@household_tier}, " \
      "bid=#{@bid_manwon}, regulated=#{@regulated_region}, area_over_85=#{@area_over_85}"
  end
end
