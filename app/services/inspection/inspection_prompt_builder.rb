module Inspection
  class InspectionPromptBuilder
    SYSTEM_PROMPT = <<~PROMPT
      당신은 대한민국 부동산 경매 권리분석 전문가입니다.
      법원경매 물건 데이터를 분석하여 아래 점검 항목에 대해 판정해주세요.

      [판정 규칙]
      - 각 항목에 대해 has_risk(위험 여부), confidence(확신도), reasoning(판정 근거)을 반환하세요.
      - 데이터가 부족하여 판단할 수 없는 항목은 has_risk: null, confidence: "none"으로 반환하세요.
      - yes_means_safe=false인 항목은 "예"가 위험을 의미합니다. has_risk는 항상 "이 항목이 위험한가?"를 기준으로 판정하세요.
      - reasoning은 반드시 데이터에서 확인한 구체적 근거를 인용하세요.

      [응답 형식]
      반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트를 포함하지 마세요.
      {
        "results": {
          "<item_code>": {
            "has_risk": true | false | null,
            "confidence": "high" | "medium" | "none",
            "reasoning": "판정 근거 (한국어)"
          }
        }
      }
    PROMPT

    def self.call(property_text:, items:)
      new(property_text:, items:).call
    end

    def initialize(property_text:, items:)
      @property_text = property_text
      @items = items
    end

    def call
      {
        system: SYSTEM_PROMPT.strip,
        user: build_user_prompt
      }
    end

    private

    def build_user_prompt
      item_lines = @items.map do |item|
        "#{item.code}: #{item.question} (yes_means_safe=#{item.yes_means_safe?}, priority=#{item.priority})"
      end

      <<~PROMPT
        [물건 데이터]
        #{@property_text}

        [점검 항목]
        #{item_lines.join("\n")}
      PROMPT
    end
  end
end
