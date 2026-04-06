class PropertyDataSyncService
  def self.call(case_number:)
    new(case_number:).call
  end

  def initialize(case_number:)
    @case_number = case_number
  end

  def call
    court_data = CourtAuctionAdapter.for.fetch_data(case_number: @case_number)
    building_data = BuildingLedgerAdapter.for.fetch_data(case_number: @case_number)
    registry_data = RegistryTranscriptAdapter.for.fetch_data(case_number: @case_number)

    return nil unless court_data

    property = Property.find_or_initialize_by(case_number: @case_number)
    property.assign_attributes(
      court_name: court_data[:court_name],
      property_type: court_data[:property_type],
      address: court_data[:address],
      appraisal_price: court_data[:appraisal_price],
      min_bid_price: court_data[:min_bid_price],
      raw_data: {
        court_auction: court_data.deep_stringify_keys,
        building_ledger: building_data&.deep_stringify_keys,
        registry_transcript: registry_data&.deep_stringify_keys
      }
    )
    property.save!
    property
  end
end
