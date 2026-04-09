class GovernmentCourtAuctionAdapter < CourtAuctionAdapter
  def initialize
    @search_client = CourtAuction::SearchClient.new
    @detail_client = CourtAuction::DetailClient.new
    @parser = CourtAuction::ResponseParser.new
    @rate_limiter = CourtAuction::RateLimiter.new
  end

  def fetch_data(case_number:)
    parsed = CourtAuction::CaseNumberParser.parse(case_number)

    @rate_limiter.throttle
    search_result = @search_client.search(**parsed)

    return nil unless search_result

    @rate_limiter.throttle
    detail_result = @detail_client.fetch(
      court_code: search_result[:court_code],
      year: parsed[:year],
      type: parsed[:type],
      number: parsed[:number],
      item_number: search_result[:item_number]
    )

    @parser.parse(search_result: search_result, detail_result: detail_result)
  end
end
