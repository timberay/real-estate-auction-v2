module CourtAuction
  class CriteriaSearchClient
    ENDPOINT = "pgjsearch/searchControllerMain.on"

    PAGE_SIZE = 10
    TIMEOUT = 30
    MAX_ITEMS_DEFAULT = 100

    REGION_CODES = {
      "서울특별시" => "11", "부산광역시" => "26", "대구광역시" => "27",
      "인천광역시" => "28", "광주광역시" => "29", "대전광역시" => "30",
      "울산광역시" => "31", "세종특별자치시" => "36", "경기도" => "41",
      "강원도" => "42", "충청북도" => "43", "충청남도" => "44",
      "전라북도" => "45", "전라남도" => "46", "경상북도" => "47",
      "경상남도" => "48", "제주특별자치도" => "50",
      "강원특별자치도" => "51", "전북특별자치도" => "52"
    }.freeze

    def self.region_code_for(address)
      return nil if address.blank?
      REGION_CODES.find { |name, _| address.start_with?(name) }&.last
    end

    def self.next_price_tier(amount)
      Pricing.next_tier(amount, tiers: Pricing::CRITERIA_MAX_FILTER_TIERS_WON)
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

    def search_all(region_code:, max_price:, max_items: MAX_ITEMS_DEFAULT)
      first_page = search(region_code: region_code, max_price: max_price, page: 1)
      all_items = first_page[:items].dup
      total_count = first_page[:total_count]

      total_pages = (total_count.to_f / PAGE_SIZE).ceil
      (2..total_pages).each do |page_no|
        break if all_items.size >= max_items
        sleep(rand(1.0..2.0))
        page_result = search(region_code: region_code, max_price: max_price, page: page_no)
        all_items.concat(page_result[:items])
      end

      { items: all_items.first(max_items), total_count: total_count }
    end

    private

    def build_connection
      Faraday.new(url: Endpoints.base_url) do |f|
        f.options.timeout = TIMEOUT
        f.options.open_timeout = 10
        f.request :json
        f.response :json
        f.headers["Accept"] = "application/json"
        f.headers["Referer"] = Endpoints.criteria_search_referer
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
          "lwsDspslPrcMin" => Pricing::MIN_BID_PRICE_WON.to_s,
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
