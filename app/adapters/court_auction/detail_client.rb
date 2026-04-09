module CourtAuction
  class DetailClient < BaseClient
    DETAIL_PATH = "/pgj/pgj15B/selectAuctnCsSrchRslt.on"
    EXPECTED_KEYS = %w[cortOfcNm csNo].freeze

    def fetch(court_code:, year:, type:, number:, item_number:)
      body = {
        cortOfcCd: court_code,
        csYr: year,
        csCdNm: type,
        csNo: number,
        csDtlNo: item_number
      }
      response = post(DETAIL_PATH, body)
      validate_structure!(response)
      response
    end

    private

    def validate_structure!(response)
      missing = EXPECTED_KEYS - response.keys
      if missing.any?
        raise DataProvider::SiteStructureChangedError,
          "Detail response missing keys: #{missing.join(', ')}"
      end
    end
  end
end
