class PropertyDataSyncService
  Result = Data.define(:court_data, :errors, :property)

  def self.call(case_number:, court_code: nil, user: nil)
    new(case_number:, court_code:).call
  end

  def initialize(case_number:, court_code: nil)
    @case_number = case_number
    @court_code = court_code
  end

  def call
    errors = {}
    court_data = nil

    begin
      adapter = GovernmentCourtAuctionAdapter.new
      if @court_code
        raw = adapter.search_case(court_code: @court_code, case_number: @case_number)
        court_data = CourtAuction::ResponseParser.new.parse_case_search(api_data: raw) if raw
      else
        court_data = adapter.fetch_data_with_detail(case_number: @case_number)
      end
    rescue DataProvider::Error => e
      Rails.logger.error("[PropertyDataSync] #{e.class}: #{e.message} (case=#{@case_number})")
      errors[:court] = e
    end

    property = persist_property(court_data) if court_data

    Result.new(court_data: court_data, errors: errors, property: property)
  end

  private

  def persist_property(court_data)
    property = Property.find_or_initialize_by(case_number: @case_number)

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
      raw_data: court_data[:raw_data]
    )
    property.save!

    sync_sale_detail(property, court_data)
    sync_auction_schedules(property, court_data[:auction_schedules])
    sync_land_details(property, court_data[:land_details])
    sync_appraisal_points(property, court_data[:appraisal_points])

    AiInspectionJob.perform_later(property)

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
    schedules.each { |attrs| property.auction_schedules.create!(attrs) }
  end

  def sync_land_details(property, lands)
    return if lands.blank?

    property.land_details.destroy_all
    lands.each { |attrs| property.land_details.create!(attrs) }
  end

  def sync_appraisal_points(property, points)
    return if points.blank?

    property.appraisal_points.destroy_all
    points.each { |attrs| property.appraisal_points.create!(attrs) }
  end
end
