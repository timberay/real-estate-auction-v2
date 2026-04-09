class PropertyDataSyncService
  Result = Data.define(:court_data, :building_data, :registry_data, :errors, :property)

  def self.call(case_number:, user: nil, with_detail: false)
    new(case_number:, user:, with_detail:).call
  end

  def initialize(case_number:, user: nil, with_detail: false)
    @case_number = case_number
    @user = user
    @with_detail = with_detail
  end

  def call
    errors = {}

    court_data = fetch_source(:court_auction, errors, :court) do |config|
      adapter = GovernmentCourtAuctionAdapter.new
      if @with_detail
        adapter.fetch_data_with_detail(case_number: @case_number)
      else
        adapter.fetch_data(case_number: @case_number)
      end
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

    # Set all property columns from court_data
    property.assign_attributes(
      property_type: court_data[:property_type],
      property_usage_code: court_data[:property_usage_code],
      status: court_data[:status],
      address: court_data[:address],
      sido: court_data[:sido],
      sigungu: court_data[:sigungu],
      dong: court_data[:dong],
      building_name: court_data[:building_name],
      building_detail: court_data[:building_detail],
      building_structure: court_data[:building_structure],
      exclusive_area: court_data[:exclusive_area],
      appraisal_price: court_data[:appraisal_price],
      min_bid_price: court_data[:min_bid_price],
      failed_bid_count: court_data[:failed_bid_count],
      view_count: court_data[:view_count],
      interest_count: court_data[:interest_count],
      latitude: court_data[:latitude],
      longitude: court_data[:longitude],
      special_conditions_code: court_data[:special_conditions_code],
      remarks: court_data[:remarks],
      case_type: court_data[:case_type],
      claim_amount: court_data[:claim_amount],
      land_category: court_data[:land_category],
      raw_data: {
        building_ledger: building_data&.deep_stringify_keys,
        registry_transcript: registry_data&.deep_stringify_keys
      }.compact
    )
    property.save!

    # Create/update sale_detail (1:1) if detail fields present
    sync_sale_detail(property, court_data)

    # Replace auction_schedules (destroy_all + create)
    sync_auction_schedules(property, court_data[:auction_schedules])

    # Replace land_details (destroy_all + create)
    sync_land_details(property, court_data[:land_details])

    # Replace appraisal_points (destroy_all + create)
    sync_appraisal_points(property, court_data[:appraisal_points])

    property
  end

  SALE_DETAIL_KEYS = %i[
    non_extinguished_rights superficies_details specification_remarks
    senior_mortgage_basis goods_remarks dividend_demand_deadline
    share_description price_round_1 price_round_2 price_round_3 price_round_4
  ].freeze

  def sync_sale_detail(property, court_data)
    detail_attrs = court_data.slice(*SALE_DETAIL_KEYS)
    return if detail_attrs.values.all?(&:blank?)

    detail = property.sale_detail || property.build_sale_detail
    detail.update!(detail_attrs)
  end

  def sync_auction_schedules(property, schedules)
    return if schedules.blank?

    property.auction_schedules.destroy_all
    schedules.each do |attrs|
      property.auction_schedules.create!(attrs)
    end
  end

  def sync_land_details(property, lands)
    return if lands.blank?

    property.land_details.destroy_all
    lands.each do |attrs|
      property.land_details.create!(attrs)
    end
  end

  def sync_appraisal_points(property, points)
    return if points.blank?

    property.appraisal_points.destroy_all
    points.each do |attrs|
      property.appraisal_points.create!(attrs)
    end
  end
end
