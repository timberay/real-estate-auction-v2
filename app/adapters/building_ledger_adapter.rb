class BuildingLedgerAdapter
  def self.for
    if ENV["USE_MOCK"] == "false"
      GovernmentBuildingLedgerAdapter.new
    else
      MockBuildingLedgerAdapter.new
    end
  end

  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end
end
