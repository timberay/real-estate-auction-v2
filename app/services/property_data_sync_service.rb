class PropertyDataSyncService
  Result = Data.define(:court_data, :building_data, :registry_data, :errors, :property)

  def self.call(case_number:, user: nil)
    new(case_number:, user:).call
  end

  def initialize(case_number:, user: nil)
    @case_number = case_number
    @user = user
  end

  def call
    errors = {}

    court_data = fetch_source(:court_auction, errors, :court) do |config|
      CourtAuctionAdapter.for(config).fetch_data(case_number: @case_number)
    end

    building_data = fetch_source(:data_go_kr, errors, :building) do |config|
      BuildingLedgerAdapter.for(config).fetch_data(case_number: @case_number)
    end

    registry_data = fetch_source_by_category(:registry, errors, :registry) do |config|
      RegistryTranscriptAdapter.for(config).fetch_data(case_number: @case_number)
    end

    property = persist_property(court_data, building_data, registry_data) if court_data

    Result.new(
      court_data: court_data,
      building_data: building_data,
      registry_data: registry_data,
      errors: errors,
      property: property
    )
  end

  private

  def fetch_source(provider_name, errors, error_key)
    config = CredentialResolver.new(user: @user, provider_name: provider_name).resolve
    yield(config)
  rescue DataProvider::Error => e
    errors[error_key] = e
    nil
  end

  def fetch_source_by_category(category, errors, error_key)
    config = CredentialResolver.new(user: @user, category: category).resolve
    yield(config)
  rescue DataProvider::Error => e
    errors[error_key] = e
    nil
  end

  def persist_property(court_data, building_data, registry_data)
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
