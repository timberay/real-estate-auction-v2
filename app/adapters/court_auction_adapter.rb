class CourtAuctionAdapter
  def self.for
    if ENV["USE_MOCK"] == "false"
      GovernmentCourtAuctionAdapter.new
    else
      MockCourtAuctionAdapter.new
    end
  end

  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end
end
