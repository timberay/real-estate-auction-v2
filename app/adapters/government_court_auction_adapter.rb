class GovernmentCourtAuctionAdapter < CourtAuctionAdapter
  def initialize
    @browser_client = CourtAuction::BrowserClient.new
    @parser = CourtAuction::ResponseParser.new
    @rate_limiter = CourtAuction::RateLimiter.new
  end

  def fetch_data(case_number:)
    parsed = CourtAuction::CaseNumberParser.parse(case_number)

    @rate_limiter.throttle
    api_response = @browser_client.fetch(**parsed)

    @parser.parse(api_response: api_response)
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
end
