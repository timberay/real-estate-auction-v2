class GovernmentBuildingLedgerAdapter < BuildingLedgerAdapter
  def fetch_data(case_number:)
    # TODO: Replace with real building ledger API calls
    MockBuildingLedgerAdapter.new.fetch_data(case_number: case_number)
  end
end
