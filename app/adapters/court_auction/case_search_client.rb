module CourtAuction
  class CaseSearchClient
    ENDPOINT = "pgj15A/selectAuctnCsSrchRslt.on"

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    COURT_CODES = {
      "서울중앙지방법원" => "B000210", "서울동부지방법원" => "B000211",
      "서울서부지방법원" => "B000215", "서울남부지방법원" => "B000212",
      "서울북부지방법원" => "B000213", "의정부지방법원" => "B000214",
      "고양지원" => "B214807", "남양주지원" => "B214804",
      "인천지방법원" => "B000240", "부천지원" => "B000241",
      "수원지방법원" => "B000250", "성남지원" => "B000251",
      "여주지원" => "B000252", "평택지원" => "B000253",
      "안산지원" => "B250826", "안양지원" => "B000254",
      "춘천지방법원" => "B000260", "강릉지원" => "B000261",
      "원주지원" => "B000262", "속초지원" => "B000263",
      "영월지원" => "B000264", "청주지방법원" => "B000270",
      "충주지원" => "B000271", "제천지원" => "B000272",
      "영동지원" => "B000273", "대전지방법원" => "B000280",
      "홍성지원" => "B000281", "논산지원" => "B000282",
      "천안지원" => "B000283", "공주지원" => "B000284",
      "서산지원" => "B000285", "대구지방법원" => "B000310",
      "안동지원" => "B000311", "경주지원" => "B000312",
      "김천지원" => "B000313", "상주지원" => "B000314",
      "의성지원" => "B000315", "영덕지원" => "B000316",
      "포항지원" => "B000317", "대구서부지원" => "B000320",
      "부산지방법원" => "B000410", "부산동부지원" => "B000412",
      "부산서부지원" => "B000414", "울산지방법원" => "B000411",
      "창원지방법원" => "B000420", "마산지원" => "B000431",
      "진주지원" => "B000421", "통영지원" => "B000422",
      "밀양지원" => "B000423", "거창지원" => "B000424",
      "광주지방법원" => "B000510", "목포지원" => "B000511",
      "장흥지원" => "B000512", "순천지원" => "B000513",
      "해남지원" => "B000514", "전주지방법원" => "B000520",
      "군산지원" => "B000521", "정읍지원" => "B000522",
      "남원지원" => "B000523", "제주지방법원" => "B000530"
    }.freeze

    REGION_TO_COURTS = {
      "서울특별시"       => %w[서울중앙지방법원 서울동부지방법원 서울서부지방법원 서울남부지방법원 서울북부지방법원],
      "부산광역시"       => %w[부산지방법원 부산동부지원 부산서부지원],
      "대구광역시"       => %w[대구지방법원 대구서부지원],
      "인천광역시"       => %w[인천지방법원 부천지원],
      "광주광역시"       => %w[광주지방법원],
      "대전광역시"       => %w[대전지방법원],
      "울산광역시"       => %w[울산지방법원],
      "세종특별자치시"   => %w[대전지방법원],
      "경기도"           => %w[수원지방법원 성남지원 안산지원 안양지원 의정부지방법원 고양지원 남양주지원 여주지원 평택지원],
      "강원도"           => %w[춘천지방법원 강릉지원 원주지원 속초지원 영월지원],
      "강원특별자치도"   => %w[춘천지방법원 강릉지원 원주지원 속초지원 영월지원],
      "충청북도"         => %w[청주지방법원 충주지원 제천지원 영동지원],
      "충청남도"         => %w[대전지방법원 홍성지원 논산지원 천안지원 공주지원 서산지원],
      "전라북도"         => %w[전주지방법원 군산지원 정읍지원 남원지원],
      "전북특별자치도"   => %w[전주지방법원 군산지원 정읍지원 남원지원],
      "전라남도"         => %w[광주지방법원 목포지원 장흥지원 순천지원 해남지원],
      "경상북도"         => %w[대구지방법원 안동지원 경주지원 김천지원 상주지원 의성지원 영덕지원 포항지원],
      "경상남도"         => %w[창원지방법원 마산지원 진주지원 통영지원 밀양지원 거창지원],
      "제주특별자치도"   => %w[제주지방법원]
    }.freeze

    def self.court_code_for(name)
      COURT_CODES[name]
    end

    def self.court_options_for(region)
      related_names = REGION_TO_COURTS[region] || []
      related_pairs = related_names.filter_map { |n| [ n, COURT_CODES[n] ] if COURT_CODES[n] }

      remaining_pairs = COURT_CODES.reject { |n, _| related_names.include?(n) }
                                   .sort_by { |n, _| n }
                                   .map { |n, c| [ n, c ] }

      groups = []
      groups << [ "관련 법원", related_pairs ] if related_pairs.any?
      groups << [ "전체 법원", remaining_pairs ]
      groups
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

    private

    def build_connection
      Faraday.new(url: Endpoints.base_url) do |f|
        f.options.open_timeout = OPEN_TIMEOUT
        f.options.timeout = READ_TIMEOUT
        f.request :json
        f.response :json, content_type: /.*/
        f.headers["Accept"] = "application/json"
        f.headers["Referer"] = Endpoints.case_search_referer
        f.headers["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36"
        f.headers["submissionid"] = "mf_wfm_mainFrame_sbm_selectCsDtlInf"
        f.headers["sc-userid"] = "NONUSER"
        f.headers["sc-pgmid"] = "PGJ15AF01"
      end
    end

    def build_request_body(court_code, cs_no)
      { "dma_srchCsDtlInf" => { "cortOfcCd" => court_code, "csNo" => cs_no } }
    end

    def handle_response(response)
      unless response.success?
        raise DataProvider::ServiceUnavailableError,
              "Court auction case search failed (#{response.status})"
      end

      data = response.body["data"]
      return nil if data.nil?

      cs_bas_inf = data["dma_csBasInf"]
      return nil if cs_bas_inf.nil? || cs_bas_inf["csNo"].blank?
      return nil if cs_bas_inf["errMsg"].present?

      data
    end
  end
end
