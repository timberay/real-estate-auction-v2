module CourtAuction
  class CaseNumberParser
    PATTERN = /\A(\d{4})(타경|타채)(\d+)\z/

    def self.parse(case_number)
      normalized = case_number.to_s.gsub(/\s+/, "")
      match = PATTERN.match(normalized)

      unless match
        raise DataProvider::ParseError, "Invalid case number format: #{case_number.inspect}"
      end

      {
        year: match[1],
        type: match[2],
        number: match[3].rjust(5, "0")
      }
    end
  end
end
