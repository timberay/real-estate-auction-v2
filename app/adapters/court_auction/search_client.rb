module CourtAuction
  class SearchClient < BaseClient
    SEARCH_PATH = "/pgj/pgjsearch/searchControllerMain.on"
    EXPECTED_KEYS = %w[totalCnt dlt_list].freeze

    def search(year:, type:, number:)
      body = build_search_body(year, type, number)
      response = post(SEARCH_PATH, body)
      validate_structure!(response)
      parse_search_result(response)
    end

    private

    def build_search_body(year, type, number)
      {
        cortAuctnSrchCondCd: "0004601",
        csYr: year,
        csCdNm: type,
        csNo: number,
        pageNo: 1,
        page: 10,
        totalCnt: 0
      }
    end

    def validate_structure!(response)
      missing = EXPECTED_KEYS - response.keys
      if missing.any?
        raise DataProvider::SiteStructureChangedError,
          "Search response missing keys: #{missing.join(', ')}"
      end
    end

    def parse_search_result(response)
      list = response["dlt_list"]
      return nil if list.nil? || list.empty?

      item = list.first
      {
        court_code: item["cortOfcCd"],
        court_name: item["cortOfcNm"],
        item_number: item["csDtlNo"],
        property_type: item["gdsMdlClsNm"],
        address: item["gdsDtlAdr"],
        appraisal_price: item["aprsAmt"].to_i,
        min_bid_price: item["lwstSaleAmt"].to_i,
        is_partial_share: item["gdsStndCd"] != "0",
        failed_bid_count: item["flbdCnt"].to_i,
        status: item["prcsCd"]
      }
    end
  end
end
