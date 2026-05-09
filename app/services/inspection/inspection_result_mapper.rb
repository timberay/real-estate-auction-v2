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
      @property_type = response.dig("metadata", "property_type")
    end

    def call
      results = @response["results"] || {}

      @items.map do |item|
        result = @property.inspection_results.find_or_initialize_by(
          inspection_item: item, user: @user
        )

        next result if result.persisted? && result.manual?

        ai_result = results[item.code]
        if ai_result.nil?
          result.assign_attributes(source_type: nil, has_risk: nil, evidence: nil)
        elsif ai_result["confidence"] == "none"
          evidence_attrs = if ai_result["reasoning"].present?
            {
              source_label: "AI 분석 (참고)",
              confidence: "none",
              reasoning: ai_result["reasoning"]
            }
          end
          result.assign_attributes(source_type: "ai", has_risk: nil, evidence: evidence_attrs)
        else
          # Medium confidence + no-risk claim: demote has_risk to nil and require user
          # confirmation (the dangerous failure mode is AI saying "no risk" when there IS risk).
          # Medium + risk claim: surface as-is so user still sees the flag.
          demote_no_risk = ai_result["confidence"] == "medium" && ai_result["has_risk"] == false
          source_label = if ai_result["confidence"] == "high"
            "AI 분석"
          elsif demote_no_risk
            "AI 의견 (확인 필요)"
          else
            "AI 분석 (추론)"
          end
          result.assign_attributes(
            source_type: "ai",
            has_risk: demote_no_risk ? nil : ai_result["has_risk"],
            evidence: {
              source_label: source_label,
              confidence: ai_result["confidence"],
              reasoning: ai_result["reasoning"]
            }
          )
        end

        # Server-side: override AI result for non-applicable property types
        if @property_type.present? && item.applicable_types.present? && !item.applicable_for?(@property_type)
          original_reasoning = ai_result&.dig("reasoning")
          override_reasoning = "해당 물건은 #{@property_type}이므로 이 항목(#{item.applicable_types.join('·')} 전용)은 직접 확인이 필요합니다."
          override_reasoning += " AI 의견: #{original_reasoning}" if original_reasoning.present?

          result.assign_attributes(
            source_type: "ai",
            has_risk: nil,
            evidence: {
              source_label: "AI 분석 (참고)",
              confidence: "none",
              reasoning: override_reasoning
            }
          )
        end

        result.save!
        result
      end
    end
  end
end
