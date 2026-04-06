module RightsAnalysis
  class ExtinguishmentBaseRightExtractor
    ELIGIBLE_TYPES = %w[근저당 가압류 압류 강제경매개시결정].freeze

    def self.call(registry_data)
      return nil if registry_data.nil?

      rights = registry_data["rights"] || []
      eligible = rights.select { |r| ELIGIBLE_TYPES.include?(r["type"]) }
      return nil if eligible.empty?

      earliest = eligible.min_by { |r| Date.parse(r["date"]) }

      {
        type: earliest["type"],
        date: Date.parse(earliest["date"]),
        holder: earliest["holder"],
        amount: earliest["amount"]
      }
    end
  end
end
