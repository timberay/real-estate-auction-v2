module CourtAuction
  class ResponseParser
    REQUIRED_FIELDS = %i[case_number address appraisal_price min_bid_price].freeze

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
        property_type: item["dspslUsgNm"],
        property_usage_code: item["maemulUtilCd"],
        status: item["mulJinYn"] == "Y" ? "진행중" : "종결",
        address: item["printSt"],
        sido: item["hjguSido"],
        sigungu: item["hjguSigu"],
        dong: item["hjguDong"],
        building_name: item["buldNm"],
        building_detail: item["buldList"],
        building_structure: item["pjbBuldList"],
        exclusive_area: item["minArea"].present? ? item["minArea"].to_f : nil,
        appraisal_price: parse_price(item["gamevalAmt"]),
        min_bid_price: parse_price(item["minmaePrice"]),
        failed_bid_count: item["yuchalCnt"].to_i,
        view_count: item["inqCnt"].to_i,
        interest_count: item["gwansMulRegCnt"].to_i,
        latitude: item["wgs84Ycordi"].present? ? item["wgs84Ycordi"].to_f : nil,
        longitude: item["wgs84Xcordi"].present? ? item["wgs84Xcordi"].to_f : nil,
        special_conditions_code: item["spJogCd"].presence,
        remarks: item["mulBigo"]
      }
    end

    def parse_price(value)
      return nil if value.blank?
      value.to_i
    end

    def parse_date(value)
      return nil if value.blank?
      Date.strptime(value, "%Y%m%d")
    rescue Date::Error
      nil
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
