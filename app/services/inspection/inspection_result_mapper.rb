module Inspection
  class InspectionResultMapper
    def self.call(response:, property:, user:, items:)
      new(response:, property:, user:, items:).call
    end

    def initialize(response:, property:, user:, items:)
      @response = response
      @property = property
      @user = user
      @items = items
    end

    def call
      results = @response["results"] || {}

      @items.map do |item|
        result = @property.inspection_results.find_or_initialize_by(
          inspection_item: item, user: @user
        )

        next result if result.persisted? && result.manual?

        ai_result = results[item.code]
        if ai_result.nil? || ai_result["confidence"] == "none"
          result.assign_attributes(source_type: nil, has_risk: nil, evidence: nil)
        else
          source_label = ai_result["confidence"] == "high" ? "AI 분석" : "AI 분석 (추론)"
          result.assign_attributes(
            source_type: "ai",
            has_risk: ai_result["has_risk"],
            evidence: {
              source_label: source_label,
              confidence: ai_result["confidence"],
              reasoning: ai_result["reasoning"]
            }
          )
        end

        result.save!
        result
      end
    end
  end
end
