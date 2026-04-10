module CourtAuction
  class CriteriaSearchClient
    BASE_URL = "https://www.courtauction.go.kr/pgj/"
    ENDPOINT = "pgjsearch/searchControllerMain.on"
    REFERER = "https://www.courtauction.go.kr/pgj/index.on?w2xPath=/pgj/ui/pgj100/PGJ151F00.xml"

    PAGE_SIZE = 10
    TIMEOUT = 30
    MIN_BID_PRICE = "50000000"

    REGION_CODES = {
      "서울특별시" => "11", "부산광역시" => "26", "대구광역시" => "27",
      "인천광역시" => "28", "광주광역시" => "29", "대전광역시" => "30",
      "울산광역시" => "31", "세종특별자치시" => "36", "경기도" => "41",
      "강원도" => "42", "충청북도" => "43", "충청남도" => "44",
      "전라북도" => "45", "전라남도" => "46", "경상북도" => "47",
      "경상남도" => "48", "제주특별자치도" => "50",
      "강원특별자치도" => "51", "전북특별자치도" => "52"
    }.freeze

    PRICE_TIERS = [
      50_000_000, 100_000_000, 150_000_000, 200_000_000, 250_000_000,
      300_000_000, 350_000_000, 400_000_000, 450_000_000, 500_000_000,
      550_000_000, 600_000_000, 650_000_000, 700_000_000, 750_000_000,
      800_000_000, 850_000_000, 900_000_000, 950_000_000, 1_000_000_000
    ].freeze

    def self.region_code_for(address)
      return nil if address.blank?
      REGION_CODES.find { |name, _| address.start_with?(name) }&.last
    end

    def self.next_price_tier(amount)
      PRICE_TIERS.find { |tier| tier > amount } || PRICE_TIERS.last
    end

    def initialize
      @connection = build_connection
    end

    def search(region_code:, max_price:, page: 1)
      response = @connection.post(ENDPOINT, build_request_body(region_code, max_price, page))
      handle_response(response)
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      raise DataProvider::ConnectionError, "Court auction criteria search failed: #{e.message}"
    end

    def search_all(region_code:, max_price:)
      first_page = search(region_code: region_code, max_price: max_price, page: 1)
      all_items = first_page[:items].dup
      total_count = first_page[:total_count]

      total_pages = (total_count.to_f / PAGE_SIZE).ceil
      (2..total_pages).each do |page_no|
        sleep(rand(1.0..2.0))
        page_result = search(region_code: region_code, max_price: max_price, page: page_no)
        all_items.concat(page_result[:items])
      end

      { items: all_items, total_count: total_count }
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
        f.headers["submissionid"] = "mf_wfm_mainFrame_sbm_selectGdsDtlSrch"
        f.headers["SC-Userid"] = "SYSTEM"
      end
    end

    def build_request_body(region_code, max_price, page)
      today = Date.current
      two_weeks = today + 14

      {
        "dma_pageInfo" => {
          "pageNo" => page,
          "pageSize" => PAGE_SIZE,
          "totalYn" => "Y"
        },
        "dma_srchGdsDtlSrchInfo" => {
          "mvprpRletDvsCd" => "00031R",
          "cortAuctnSrchCondCd" => "0004601",
          "pgmId" => "PGJ151F01",
          "statNum" => 1,
          "cortStDvs" => "3",
          "csNo" => "",
          "cortOfcCd" => "",
          "bidDvsCd" => "",
          "rdnmSdCd" => region_code,
          "rdnmSggCd" => "",
          "rdnmNo" => "",
          "lclDspslGdsLstUsgCd" => "20000",
          "mclDspslGdsLstUsgCd" => "20100",
          "sclDspslGdsLstUsgCd" => "",
          "lwsDspslPrcMin" => MIN_BID_PRICE,
          "lwsDspslPrcMax" => max_price.to_s,
          "notifyLoc" => "on",
          "bidBgngYmd" => today.strftime("%Y%m%d"),
          "bidEndYmd" => two_weeks.strftime("%Y%m%d")
        }
      }
    end

    def handle_response(response)
      unless response.success?
        raise DataProvider::ServiceUnavailableError,
          "Court auction criteria search failed (#{response.status})"
      end

      body = response.body
      items = body.dig("data", "dlt_srchResult") || []
      total_count = body.dig("data", "dma_pageInfo", "totalCnt").to_i

      { items: items, total_count: total_count }
    end
  end
end
