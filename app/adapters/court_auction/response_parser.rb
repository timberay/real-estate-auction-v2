module CourtAuction
  class ResponseParser
    REQUIRED_FIELDS = %i[case_number court_name address appraisal_price min_bid_price].freeze

    def parse(search_result:, detail_result:)
      result = build_result(search_result, detail_result)
      validate!(result)
      result
    end

    private

    def build_result(search, detail)
      {
        case_number: "#{detail['csYr']}#{detail['csCdNm']}#{detail['csNo']}",
        court_name: search[:court_name],
        property_type: search[:property_type],
        address: search[:address],
        appraisal_price: search[:appraisal_price],
        min_bid_price: search[:min_bid_price],
        remarks: detail["bkgsRmk"] || "",
        non_extinguished_rights: parse_rights(detail["dlt_neRghts"]),
        tenants: parse_tenants(detail["dlt_tenants"]),
        separate_land_registry: yn_to_bool(detail["sprtLandRgstYn"]),
        lien_reported: yn_to_bool(detail["lienRptYn"]),
        use_approval: yn_to_bool(detail["useAprYn"]),
        wall_partition_issue: yn_to_bool(detail["wlpttIsuYn"]),
        is_partial_share: search[:is_partial_share],
        failed_bid_count: search[:failed_bid_count],
        status: search[:status],
        sale_schedule: parse_schedule(detail["dlt_dxdyDts"])
      }
    end

    def parse_rights(rights)
      return [] unless rights.is_a?(Array)
      rights.map { |r| r["rghtsNm"] }.compact
    end

    def parse_tenants(tenants)
      return [] unless tenants.is_a?(Array)
      tenants.map do |t|
        {
          name: t["tnntNm"],
          deposit: t["dpstAmt"]&.to_i,
          move_in_date: parse_date(t["mvnDt"]),
          dividend_requested: yn_to_bool(t["dvdReqYn"])
        }
      end
    end

    def parse_schedule(dates)
      return [] unless dates.is_a?(Array)
      dates.map do |d|
        {
          date: parse_date(d["dxdyDt"]),
          min_price: d["lwstSaleAmt"]&.to_i,
          result: d["dxdyRslt"]
        }
      end
    end

    def yn_to_bool(value)
      value == "Y"
    end

    def parse_date(yyyymmdd)
      return nil unless yyyymmdd.is_a?(String) && yyyymmdd.length == 8
      "#{yyyymmdd[0..3]}-#{yyyymmdd[4..5]}-#{yyyymmdd[6..7]}"
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
