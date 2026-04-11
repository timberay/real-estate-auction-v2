module Inspection
  class PdfPromptBuilder
    SYSTEM_PROMPT = <<~PROMPT
      당신은 대한민국 부동산 경매 권리분석 전문가입니다.
      첨부된 PDF 문서들을 분석하여 아래 작업을 수행하세요.

      [작업 1: 메타데이터 추출]
      문서에서 다음 정보를 추출하세요:
      - court_name: 관할 법원명
      - case_number: 사건번호 (예: 2024타경964)
      - address: 소재지
      - property_type: 물건종류
      - appraisal_price: 감정가 (숫자)
      - min_bid_price: 최저입찰가 (숫자)

      [작업 2: 점검항목 판정]
      각 항목에 대해 has_risk, confidence, reasoning을 반환하세요.

      [판정 규칙]
      - 데이터가 부족하여 판단할 수 없는 항목은 has_risk: null, confidence: "none"으로 반환하세요.
      - yes_means_safe=false인 항목은 "예"가 위험을 의미합니다. has_risk는 항상 "이 항목이 위험한가?"를 기준으로 판정하세요.
      - reasoning은 반드시 문서에서 확인한 구체적 근거를 인용하세요.

      [응답 형식]
      반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트를 포함하지 마세요.
      {
        "metadata": {
          "court_name": "...",
          "case_number": "...",
          "address": "...",
          "property_type": "...",
          "appraisal_price": ...,
          "min_bid_price": ...
        },
        "results": {
          "<item_code>": {
            "has_risk": true | false | null,
            "confidence": "high" | "medium" | "none",
            "reasoning": "판정 근거 (한국어, 문서 인용 포함)"
          }
        }
      }
    PROMPT

    def self.call(items:)
      new(items:).call
    end

    def initialize(items:)
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
        [첨부 문서]
        (첨부된 PDF 문서들을 분석해주세요)

        [점검 항목]
        #{item_lines.join("\n")}
      PROMPT
    end
  end
end
