class BuildingLedgerAdapter
  def self.for(config = {})
    if config[:adapter] == :real
      GovernmentBuildingLedgerAdapter.new(api_key: config[:api_key])
    else
      MockBuildingLedgerAdapter.new
    end
  end

  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end
end
