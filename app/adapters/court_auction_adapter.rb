class CourtAuctionAdapter
  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end

  def fetch_data_with_detail(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data_with_detail must be implemented"
  end

  def search_by_criteria(region:, year:, min_price:, max_price:)
    raise NotImplementedError, "#{self.class}#search_by_criteria must be implemented"
  end
end
