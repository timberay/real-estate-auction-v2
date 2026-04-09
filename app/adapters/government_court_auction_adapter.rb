class GovernmentCourtAuctionAdapter < CourtAuctionAdapter
  def initialize
    @browser_client = CourtAuction::BrowserClient.new
    @parser = CourtAuction::ResponseParser.new
    @rate_limiter = CourtAuction::RateLimiter.new
  end

  def fetch_data(case_number:)
    parsed = CourtAuction::CaseNumberParser.parse(case_number)

    @rate_limiter.throttle
    api_response = @browser_client.fetch_with_detail(**parsed)

    # Return search-only parse for backward compat
    @parser.parse(api_response: api_response["search"])
  end

  def fetch_data_with_detail(case_number:)
    parsed = CourtAuction::CaseNumberParser.parse(case_number)

    @rate_limiter.throttle
    combined = @browser_client.fetch_with_detail(**parsed)

    @parser.parse_with_detail(
      search_response: combined["search"],
      detail_response: combined["detail"]
    )
  end

  def search_by_criteria(region:, year:, min_price:, max_price:)
    @rate_limiter.throttle
    @browser_client.search_by_criteria(
      region: region,
      year: year,
      min_price: min_price,
      max_price: max_price
    )
  end
end
