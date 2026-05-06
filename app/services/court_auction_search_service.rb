class CourtAuctionSearchService
  MAX_ITEMS = 20
  PAGE_SIZE = 8

  Result = Data.define(:count, :error)

  def self.call(user:, address:, max_bid_price:)
    new(user: user, address: address, max_bid_price: max_bid_price).call
  end

  def initialize(user:, address:, max_bid_price:)
    @user = user
    @address = address
    @max_bid_price = max_bid_price
  end

  def call
    region_code = CourtAuction::CriteriaSearchClient.region_code_for(@address)
    unless region_code
      return Result.new(count: 0, error: ArgumentError.new("Unknown region in address: #{@address}"))
    end

    max_price = CourtAuction::CriteriaSearchClient.next_price_tier(@max_bid_price)

    adapter = GovernmentCourtAuctionAdapter.new
    response = adapter.search_by_criteria(
      region_code: region_code,
      max_price: max_price,
      max_items: MAX_ITEMS
    )

    saved_count = persist_results(response[:items], response[:total_count])

    Rails.logger.info(
      "[CourtAuctionSearch] region=#{region_code} max_price=#{max_price} " \
      "total=#{response[:total_count]} saved=#{saved_count}"
    )

    Result.new(count: saved_count, error: nil)
  rescue DataProvider::Error => e
    Result.new(count: 0, error: e)
  end

  private

  def persist_results(items, api_total_count)
    ActiveRecord::Base.transaction do
      @user.update!(last_search_api_total_count: api_total_count)
      @user.search_results.destroy_all

      deduplicated = deduplicate_by_case_number(items)

      deduplicated.each do |item, property_count|
        @user.search_results.create!(
          case_number: item["srnSaNo"],
          court_name: item["jiwonNm"],
          court_code: item["boCd"],
          address: item["printSt"],
          appraisal_price: item["gamevalAmt"].to_i,
          min_bid_price: item["minmaePrice"].to_i,
          property_type: item["dspslUsgNm"],
          status: CourtAuction::Status.from_property_flag(item["mulJinYn"]),
          failed_bid_count: item["yuchalCnt"].to_i,
          auction_date: item["maeGiil"],
          remarks: item["mulBigo"],
          property_count: property_count
        )
      end

      deduplicated.size
    end
  end

  def deduplicate_by_case_number(items)
    grouped = items.group_by { |i| i["srnSaNo"] }
    grouped.map { |_, group| [ group.first, group.size ] }
  end
end
