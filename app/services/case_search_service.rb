class CaseSearchService
  Result = Data.define(:properties, :error) do
    def success?
      error.nil?
    end
  end

  def self.call(court_code:, case_number:)
    new.search(court_code: court_code, case_number: case_number)
  end

  def self.call_by_serial(court_code:, serial_number:)
    new.search_by_serial(court_code: court_code, serial_number: serial_number)
  end

  def initialize
    @adapter = GovernmentCourtAuctionAdapter.new
  end

  def search(court_code:, case_number:)
    data = @adapter.search_case(court_code: court_code, case_number: case_number)

    if data
      property = persist(case_number, data)
      Result.new(properties: [ property ], error: nil)
    else
      Result.new(properties: [], error: "Case #{case_number} not found")
    end
  rescue DataProvider::Error => e
    log_error(e, case_number)
    Result.new(properties: [], error: "API connection failed: #{e.message}")
  end

  def search_by_serial(court_code:, serial_number:)
    results = @adapter.search_case_by_serial(court_code: court_code, serial_number: serial_number)

    if results.empty?
      return Result.new(properties: [], error: "No cases found for serial number #{serial_number}")
    end

    properties = results.map { |r| persist(r[:case_number], r[:data]) }
    Result.new(properties: properties, error: nil)
  rescue DataProvider::Error => e
    log_error(e, serial_number)
    Result.new(properties: [], error: "API connection failed: #{e.message}")
  end

  private

  def persist(case_number, data)
    property = Property.find_or_initialize_by(case_number: case_number)
    property.update!(raw_data: data)
    property
  end

  def log_error(error, identifier)
    Rails.logger.error("[CaseSearchService] #{error.class}: #{error.message} (#{identifier})")
  end
end
