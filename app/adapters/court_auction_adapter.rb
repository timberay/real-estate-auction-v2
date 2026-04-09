class CourtAuctionAdapter
  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end

  def fetch_data_with_detail(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data_with_detail must be implemented"
  end
end
