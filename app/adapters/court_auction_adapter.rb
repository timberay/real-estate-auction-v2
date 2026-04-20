class CourtAuctionAdapter
  def search_by_criteria(region_code:, max_price:, max_items: 100)
    raise NotImplementedError, "#{self.class}#search_by_criteria must be implemented"
  end
end
