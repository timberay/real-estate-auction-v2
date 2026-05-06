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

    def parse_case_search(api_data:)
      cs_bas = api_data["dma_csBasInf"]
      return nil if cs_bas.nil? || cs_bas["csNo"].blank?

      goods     = (api_data["dlt_dspslGdsDspslObjctLst"] || []).first || {}
      objects   = (api_data["dlt_rletCsDspslObjctLst"]   || []).first || {}
      demand    = (api_data["dlt_dstrtDemnLstprdDts"]    || []).first || {}
      schedules =  api_data["dlt_rletCsGdsDtsDxdyInf"]   || []

      {
        case_number:             cs_bas["userCsNo"],
        case_type:               cs_bas["csNm"],
        court_code:              cs_bas["cortOfcCd"],
        court_name:              cs_bas["cortOfcNm"],
        claim_amount:            parse_price(cs_bas["clmAmt"]),
        status:                  parse_case_status(cs_bas["csProgStatCd"]),
        property_type:           objects["auctnLstNm"],
        address:                 goods["userSt"],
        sido:                    goods["adongSdNm"],
        sigungu:                 goods["adongSggNm"],
        dong:                    goods["adongEmdNm"],
        building_name:           goods["bldNm"].presence || demand["bldNm"],
        building_detail:         goods["bldDtlDts"],
        appraisal_price:         parse_price(goods["aeeEvlAmt"]),
        min_bid_price:           parse_price(goods["fstPbancLwsDspslPrc"]),
        failed_bid_count:        count_failed_bids(schedules),
        remarks:                 goods["dspslGdsRmk"],
        special_conditions_code: goods["bidDvsCd"],
        property_count:          (api_data["dlt_dspslGdsDspslObjctLst"] || []).length.clamp(1, 99)
      }
    end

    private

    def parse_case_status(code)
      Status.from_progress_code(code)
    end

    def count_failed_bids(schedules)
      schedules.count { |s| Status.failed_bid?(s["auctnDxdyRsltCd"]) }
    end

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
        status: Status.from_property_flag(item["mulJinYn"]),
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
