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

      [작업 3: 권리분석]
      등기부등본과 매각물건명세서를 종합하여 권리분석 데이터를 추출하세요.
      금액은 반드시 원(₩) 단위 숫자로 반환하세요.

      - verdict: "safe" | "caution" | "danger" — 낙찰자 입장의 종합 위험도
      - verdict_summary: 한줄 요약 (한국어)
      - base_right_type: 말소기준권리 유형 ("근저당권", "전세권", "가압류", "담보가등기" 등)
      - base_right_holder: 말소기준권리 권리자명
      - base_right_date: 말소기준권리 설정일 (YYYY-MM-DD)
      - opportunity_type: null | "gap_investment" | "occupancy"
      - opportunity_reason: 기회 요인 설명 (없으면 null)
      - tenants: 임차인 배열. 각 항목은 { name, deposit(원), move_in_date(YYYY-MM-DD), opposing_power(boolean), priority_rank(정수) }
      - rights_timeline: 권리 설정 내역 배열. 각 항목은 { date(YYYY-MM-DD), type, holder, amount(원), extinguished_on_sale(boolean) }
      - reasoning: 분석 과정과 판단 근거를 단계적으로 서술하세요 (Chain of Thought). 어떤 권리가 말소되고 어떤 권리가 인수되는지 명시적으로 설명하세요.
      - checklist_references: 관련된 점검항목 코드 배열 (예: ["rights-002"])

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
        },
        "rights_analysis": {
          "verdict": "safe" | "caution" | "danger",
          "verdict_summary": "...",
          "base_right_type": "...",
          "base_right_holder": "...",
          "base_right_date": "YYYY-MM-DD",
          "opportunity_type": null | "gap_investment" | "occupancy",
          "opportunity_reason": null | "...",
          "tenants": [{ "name": "...", "deposit": 0, "move_in_date": "YYYY-MM-DD", "opposing_power": true, "priority_rank": 1 }],
          "rights_timeline": [{ "date": "YYYY-MM-DD", "type": "...", "holder": "...", "amount": 0, "extinguished_on_sale": true }],
          "reasoning": "...",
          "checklist_references": ["..."]
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
