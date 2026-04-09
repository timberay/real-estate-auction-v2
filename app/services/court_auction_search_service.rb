class CourtAuctionSearchService
  Result = Data.define(:count, :error)

  def self.call(user:)
    new(user:).call
  end

  def initialize(user:)
    @user = user
  end

  def call
    bs = @user.budget_setting

    region = bs&.effective_region || BudgetSetting::DEFAULT_REGION
    year = Time.current.year.to_s
    max_price = bs&.max_price_option || BudgetSetting::DEFAULT_MAX_PRICE

    adapter = GovernmentCourtAuctionAdapter.new
    response = adapter.search_by_criteria(
      region: region,
      year: year,
      min_price: 50_000_000,
      max_price: max_price
    )

    saved_count = persist_results(response[:items])

    Rails.logger.info "[CourtAuctionSearch] API total=#{response[:total]}, items=#{response[:items].size}, saved=#{saved_count}"

    Result.new(count: saved_count, error: nil)
  rescue DataProvider::Error => e
    Result.new(count: 0, error: e)
  end

  private

  def persist_results(items)
    @user.search_results.destroy_all

    deduplicated = deduplicate_by_case_number(items)

    deduplicated.each do |item, property_count|
      @user.search_results.create!(
        case_number: item["srnSaNo"],
        court_name: item["jiwonNm"],
        address: item["printSt"],
        appraisal_price: item["gamevalAmt"].to_i,
        min_bid_price: item["minmaePrice"].to_i,
        property_type: item["dspslUsgNm"],
        status: item["mulJinYn"] == "Y" ? "진행중" : "종결",
        failed_bid_count: item["yuchalCnt"].to_i,
        auction_date: item["maeGiil"],
        remarks: item["mulBigo"],
        property_count: property_count
      )
    end

    deduplicated.size
  end

  def deduplicate_by_case_number(items)
    grouped = items.group_by { |i| i["srnSaNo"] }
    grouped.map { |_, group| [ group.first, group.size ] }
  end
end
