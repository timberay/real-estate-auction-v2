module CourtAuction
  class CaseSearchClient
    BASE_URL = "https://www.courtauction.go.kr/pgj/"
    ENDPOINT = "pgj15A/selectAuctnCsSrchRslt.on"
    REFERER = "https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ159M00.xml"

    CASE_TYPE = "타경"
    DEFAULT_YEAR_RANGE = 5
    TIMEOUT = 30

    COURT_CODES = {
      "서울중앙지방법원" => "B000210",
      "서울동부지방법원" => "B000211",
      "서울서부지방법원" => "B000215",
      "서울남부지방법원" => "B000212",
      "서울북부지방법원" => "B000213",
      "의정부지방법원" => "B000214",
      "고양지원" => "B214807",
      "남양주지원" => "B214804",
      "인천지방법원" => "B000240",
      "부천지원" => "B000241",
      "수원지방법원" => "B000250",
      "성남지원" => "B000251",
      "여주지원" => "B000252",
      "평택지원" => "B000253",
      "안산지원" => "B250826",
      "안양지원" => "B000254",
      "춘천지방법원" => "B000260",
      "강릉지원" => "B000261",
      "원주지원" => "B000262",
      "속초지원" => "B000263",
      "영월지원" => "B000264",
      "청주지방법원" => "B000270",
      "충주지원" => "B000271",
      "제천지원" => "B000272",
      "영동지원" => "B000273",
      "대전지방법원" => "B000280",
      "홍성지원" => "B000281",
      "논산지원" => "B000282",
      "천안지원" => "B000283",
      "공주지원" => "B000284",
      "서산지원" => "B000285",
      "대구지방법원" => "B000310",
      "안동지원" => "B000311",
      "경주지원" => "B000312",
      "김천지원" => "B000313",
      "상주지원" => "B000314",
      "의성지원" => "B000315",
      "영덕지원" => "B000316",
      "포항지원" => "B000317",
      "대구서부지원" => "B000320",
      "부산지방법원" => "B000410",
      "부산동부지원" => "B000412",
      "부산서부지원" => "B000414",
      "울산지방법원" => "B000411",
      "창원지방법원" => "B000420",
      "마산지원" => "B000431",
      "진주지원" => "B000421",
      "통영지원" => "B000422",
      "밀양지원" => "B000423",
      "거창지원" => "B000424",
      "광주지방법원" => "B000510",
      "목포지원" => "B000511",
      "장흥지원" => "B000512",
      "순천지원" => "B000513",
      "해남지원" => "B000514",
      "전주지방법원" => "B000520",
      "군산지원" => "B000521",
      "정읍지원" => "B000522",
      "남원지원" => "B000523",
      "제주지방법원" => "B000530"
    }.freeze

    PRIORITY_COURTS = %w[
      서울중앙지방법원 서울동부지방법원 서울서부지방법원 서울남부지방법원 서울북부지방법원
      수원지방법원 성남지원 안산지원 안양지원 의정부지방법원 고양지원 남양주지원
      인천지방법원 부천지원
    ].freeze

    def self.priority_court_codes
      priority = PRIORITY_COURTS.filter_map { |name| [ name, COURT_CODES[name] ] if COURT_CODES[name] }
      remaining = COURT_CODES.reject { |name, _| PRIORITY_COURTS.include?(name) }.to_a
      priority + remaining
    end

    def self.court_code_for(court_name)
      COURT_CODES[court_name]
    end

    def self.court_names
      COURT_CODES.keys
    end

    def initialize
      @connection = build_connection
    end

    def search(court_code:, case_number:)
      response = @connection.post(ENDPOINT, build_request_body(court_code, case_number))
      handle_response(response)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise DataProvider::ConnectionError, "Court auction connection failed: #{e.message}"
    end

    def search_by_serial(court_code:, serial_number:, year_range: DEFAULT_YEAR_RANGE)
      current_year = Date.current.year
      results = []

      current_year.downto(current_year - year_range).each do |year|
        cs_no = "#{year}#{CASE_TYPE}#{serial_number}"
        data = search(court_code: court_code, case_number: cs_no)

        results << { year: year, case_number: cs_no, data: data } if data

        sleep(rand(1.5..3.0)) unless year == current_year - year_range
      end

      results
    end

    private

    def build_connection
      Faraday.new(url: BASE_URL) do |f|
        f.options.timeout = TIMEOUT
        f.options.open_timeout = 10
        f.request :json
        f.response :json
        f.headers["Accept"] = "application/json"
        f.headers["Referer"] = REFERER
        f.headers["submissionid"] = "mf_wfm_mainFrame_sbm_selectCsDtlInf"
        f.headers["sc-userid"] = "NONUSER"
        f.headers["sc-pgmid"] = "PGJ15AF01"
      end
    end

    def build_request_body(court_code, cs_no)
      {
        "dma_srchCsDtlInf" => {
          "cortOfcCd" => court_code,
          "csNo" => cs_no
        }
      }
    end

    def handle_response(response)
      unless response.success?
        raise DataProvider::ServiceUnavailableError,
          "Court auction case search failed (#{response.status})"
      end

      body = response.body
      result = body.dig("data", "dma_result")
      return nil if result.nil?
      return nil if invalid_case?(result)

      result
    end

    def invalid_case?(result)
      result["errMsg"].present? ||
        result.dig("csBaseInfo").blank? ||
        result.dig("csBaseInfo", "csNo").blank?
    end
  end
end
