class GovernmentCourtAuctionAdapter < CourtAuctionAdapter
  def fetch_data(case_number:)
    # TODO: Replace with real courtauction.go.kr API calls
    MockCourtAuctionAdapter.new.fetch_data(case_number: case_number)
  end
end
