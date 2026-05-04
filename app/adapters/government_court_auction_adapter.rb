class GovernmentCourtAuctionAdapter < CourtAuctionAdapter
  def initialize
    @browser_client = CourtAuction::BrowserClient.new
    @criteria_search_client = CourtAuction::CriteriaSearchClient.new
    @case_search_client = CourtAuction::CaseSearchClient.new
    @parser = CourtAuction::ResponseParser.new
    @rate_limiter = CourtAuction::RateLimiter.new
  end

  def search_by_criteria(region_code:, max_price:, max_items: 100)
    @rate_limiter.throttle
    @criteria_search_client.search_all(region_code: region_code, max_price: max_price, max_items: max_items)
  end

  def search_case(court_code:, case_number:)
    @rate_limiter.throttle
    @case_search_client.search(court_code: court_code, case_number: case_number)
  end
end
