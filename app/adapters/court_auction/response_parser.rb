module CourtAuction
  class ResponseParser
    REQUIRED_FIELDS = %i[case_number court_name address appraisal_price min_bid_price].freeze

    def parse(api_response:)
      items = extract_items(api_response)
      return nil if items.nil? || items.empty?

      item = items.first
      result = build_result(item)
      validate!(result)
      result
    end

    private

    def extract_items(response)
      items = response.dig("data", "dlt_srchResult")
      raise DataProvider::ParseError, "Unexpected response structure" if items.nil?
      items
    rescue NoMethodError
      raise DataProvider::ParseError, "Unexpected response structure"
    end

    def build_result(item)
      {
        case_number: item["srnSaNo"],
        court_name: item["jiwonNm"],
        property_type: item["dspslUsgNm"],
        address: item["printSt"],
        appraisal_price: parse_price(item["gamevalAmt"]),
        min_bid_price: parse_price(item["minmaePrice"]),
        remarks: item["mulBigo"] || "",
        failed_bid_count: item["yuchalCnt"].to_i,
        is_partial_share: item["mokGbncd"] != "00",
        special_conditions: item["spJogCd"] || "",
        view_count: item["inqCnt"].to_i
      }
    end

    def parse_price(value)
      return nil if value.blank?
      value.to_i
    end

    def validate!(result)
      missing = REQUIRED_FIELDS.select { |f| result[f].blank? }
      if missing.any?
        raise DataProvider::ParseError,
          "Missing required fields: #{missing.join(', ')}"
      end
    end
  end
end
