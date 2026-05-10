module Properties
  class BulkImportService
    MAX_ROWS = 50

    Row = Data.define(:line_number, :raw, :court_name, :court_code, :case_number, :property, :error_message, :already_existed)
    Result = Data.define(:succeeded, :failed, :truncated_count) do
      def total = succeeded.size + failed.size
    end

    def self.call(user:, raw_input:)
      new(user: user, raw_input: raw_input).call
    end

    def initialize(user:, raw_input:)
      @user = user
      @raw_input = raw_input.to_s
    end

    def call
      lines = parse_input
      total_input = lines.size
      truncated_count = [ total_input - MAX_ROWS, 0 ].max
      lines = lines.first(MAX_ROWS)
      succeeded = []
      failed = []

      lines.each do |row|
        process_row(row, succeeded, failed)
      end

      Result.new(succeeded: succeeded, failed: failed, truncated_count: truncated_count)
    end

    private

    HEADER_PATTERN = /\A(법원|court)\s*[,\t]\s*(사건번호|case_number)\z/i
    CASE_NUMBER_PATTERN = /\d{4}(타경|타채)\d+/
    SEPARATOR_PATTERN = /[,\t\s]+/

    def parse_input
      rows = []
      line_number = 0

      @raw_input.each_line do |raw_line|
        raw_line = raw_line.strip
        next if raw_line.empty?
        next if raw_line.start_with?("#")
        next if HEADER_PATTERN.match?(raw_line.gsub(SEPARATOR_PATTERN, ","))

        line_number += 1
        rows << parse_line(raw_line, line_number)
      end

      rows
    end

    def parse_line(raw, line_number)
      parts = raw.split(SEPARATOR_PATTERN, 2)

      if parts.size == 2
        court_name = parts[0].strip
        case_number_candidate = parts[1].strip.gsub(/\s+/, "")
        if CASE_NUMBER_PATTERN.match?(case_number_candidate)
          return Row.new(
            line_number: line_number, raw: raw,
            court_name: court_name, court_code: nil,
            case_number: case_number_candidate,
            property: nil, error_message: nil, already_existed: false
          )
        end
      end

      Row.new(
        line_number: line_number, raw: raw,
        court_name: nil, court_code: nil, case_number: nil,
        property: nil,
        error_message: "형식 오류: '#{raw}' — 예시 형식 '서울중앙지방법원,2026타경1234'",
        already_existed: false
      )
    end

    def process_row(row, succeeded, failed)
      if row.error_message.present?
        failed << row
        return
      end

      court_code = CourtAuction::CaseSearchClient::COURT_CODES[row.court_name]
      unless court_code
        failed << Row.new(**row.to_h.merge(error_message: "등록되지 않은 법원: '#{row.court_name}'"))
        return
      end

      begin
        CourtAuction::CaseNumberParser.parse(row.case_number)
      rescue DataProvider::ParseError
        failed << Row.new(**row.to_h.merge(error_message: "사건번호 형식 오류: '#{row.case_number}' (예: 2026타경1234)"))
        return
      end

      result = CaseSearchService.call(court_code: court_code, case_number: row.case_number)

      if result.error
        failed << Row.new(**row.to_h.merge(court_code: court_code, error_message: localized_error(result.error)))
        return
      end

      property = result.properties.first
      user_property = @user.user_properties.find_by(property: property)
      already_existed = user_property.present?
      @user.user_properties.find_or_create_by!(property: property)
      succeeded << Row.new(**row.to_h.merge(court_code: court_code, property: property, already_existed: already_existed))
    end

    def localized_error(error)
      case error
      when DataProvider::TimeoutError
        "데이터 수집 시간이 초과되었습니다. 다시 시도해주세요."
      when DataProvider::ServiceUnavailableError, DataProvider::ConnectionError
        "법원경매 사이트에 접속할 수 없습니다. 잠시 후 다시 시도해주세요."
      when DataProvider::ConfigurationError
        "브라우저 실행에 실패했습니다. 시스템 설정을 확인해주세요."
      when DataProvider::DataNotFoundError, nil
        "해당 사건번호의 데이터를 찾을 수 없습니다."
      else
        "데이터 수집 중 오류가 발생했습니다. 다시 시도해주세요."
      end
    end
  end
end
