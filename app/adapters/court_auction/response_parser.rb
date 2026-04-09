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

    def parse_with_detail(search_response:, detail_response:)
      result = parse(api_response: search_response)
      return nil if result.nil?

      detail = extract_detail(detail_response)
      return result if detail.nil?

      merge_detail(result, detail)
    end

    private

    def extract_items(response)
      items = response.dig("data", "dlt_srchResult")
      raise DataProvider::ParseError, "Unexpected response structure" if items.nil?
      items
    rescue NoMethodError
      raise DataProvider::ParseError, "Unexpected response structure"
    end

    def extract_detail(response)
      response.dig("data", "dma_result")
    rescue NoMethodError
      nil
    end

    def build_result(item)
      {
        case_number: item["srnSaNo"],
        property_type: item["dspslUsgNm"],
        property_usage_code: item["dspslUsgNm"],
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

    def merge_detail(result, detail)
      cs_base = detail["csBaseInfo"] || {}
      dxdy = detail["dspslGdsDxdyInfo"] || {}
      objct = (detail["gdsDspslObjctLst"] || []).first || {}

      # From csBaseInfo
      result[:case_type] = cs_base["csNm"]
      result[:claim_amount] = parse_price(cs_base["clmAmt"])

      # From dspslGdsDxdyInfo
      rights_text = dxdy["ndstrcRghCtt"]
      result[:non_extinguished_rights] = normalize_empty_text(rights_text)
      result[:superficies_details] = dxdy["sfciesDetails"]
      result[:specification_remarks] = dxdy["gdsSpcfcRmk"]
      result[:senior_mortgage_basis] = dxdy["tprtyRnkHypthcStngDts"]
      result[:goods_remarks] = dxdy["dspslGdsRmk"]
      result[:price_round_1] = parse_price(dxdy["tsLwsDspslPrc1"])
      result[:price_round_2] = parse_price(dxdy["tsLwsDspslPrc2"])
      result[:price_round_3] = parse_price(dxdy["tsLwsDspslPrc3"])
      result[:price_round_4] = parse_price(dxdy["tsLwsDspslPrc4"])

      # From gdsDspslObjctLst[0] — overrides search values
      result[:land_category] = objct["rletDvsDts"] if objct["rletDvsDts"].present?
      result[:building_detail] = objct["bldDtlDts"] if objct["bldDtlDts"].present?
      result[:building_name] = objct["bldNm"] if objct["bldNm"].present?
      result[:building_structure] = objct["pjbBuldList"] if objct["pjbBuldList"].present?
      result[:share_description] = objct["dspslStkCtt"]

      # From dstrtDemnInfo[0]
      demand_info = (detail["dstrtDemnInfo"] || []).first
      if demand_info&.dig("dstrtDemnLstprdYmd").present?
        result[:dividend_demand_deadline] = parse_date(demand_info["dstrtDemnLstprdYmd"])
      end

      # Auction schedules from gdsDspslDxdyLst
      result[:auction_schedules] = parse_auction_schedules(detail["gdsDspslDxdyLst"])

      # Land details from rgltLandLstAll (nested arrays — flat_map)
      result[:land_details] = parse_land_details(detail["rgltLandLstAll"])

      # Appraisal points from aeeWevlMnpntLst
      result[:appraisal_points] = parse_appraisal_points(detail["aeeWevlMnpntLst"])

      result
    end

    def normalize_empty_text(text)
      return nil if text.blank?
      return nil if text.strip == "해당사항없음"
      text
    end

    def parse_auction_schedules(schedule_list)
      return [] if schedule_list.blank?
      schedule_list.map do |s|
        {
          schedule_date: parse_date(s["dxdyYmd"]),
          schedule_time: s["dxdyHm"],
          place: s["dxdyPlcNm"],
          schedule_type: s["auctnDxdyKndCd"],
          result_code: s["auctnDxdyRsltCd"],
          min_price: parse_price(s["tsLwsDspslPrc"]),
          sale_amount: parse_price(s["dspslAmt"])
        }
      end
    end

    def parse_land_details(land_list)
      return [] if land_list.blank?
      land_list.flat_map do |group|
        next [] unless group.is_a?(Array)
        group.map do |l|
          {
            land_type: l["rletDvsDts"],
            land_area: l["landArea"],
            land_category: l["ldcgCd"],
            share_ratio: l["shrRt"],
            address: l["printSt"],
            lot_number: l["lotNo"]
          }
        end
      end
    end

    def parse_appraisal_points(points_list)
      return [] if points_list.blank?
      points_list.map do |p|
        {
          item_code: p["aeeWevlMnpntItmCd"],
          content: p["aeeWevlMnpntCtt"]
        }
      end
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
