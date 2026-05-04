class CaseSearchService
  Result = Data.define(:properties, :error) do
    def success? = error.nil?
  end

  def self.call(court_code:, case_number:)
    new.call(court_code: court_code, case_number: case_number)
  end

  def initialize
    @adapter = GovernmentCourtAuctionAdapter.new
    @parser = CourtAuction::ResponseParser.new
  end

  def call(court_code:, case_number:)
    api_data = @adapter.search_case(court_code: court_code, case_number: case_number)
    parsed = api_data && @parser.parse_case_search(api_data: api_data)

    if parsed.nil?
      return Result.new(
        properties: [],
        error: DataProvider::DataNotFoundError.new("Case #{case_number} not found at court #{court_code}")
      )
    end

    property = persist(parsed)
    Result.new(properties: [ property ], error: nil)
  rescue DataProvider::Error => e
    Rails.logger.error("[CaseSearchService] #{e.class}: #{e.message} (case=#{case_number})")
    Result.new(properties: [], error: e)
  end

  private

  def persist(parsed)
    Property.find_or_create_by!(case_number: parsed[:case_number]) do |p|
      p.assign_attributes(parsed)
    end
  rescue ActiveRecord::RecordNotUnique
    Property.find_by!(case_number: parsed[:case_number])
  end
end
