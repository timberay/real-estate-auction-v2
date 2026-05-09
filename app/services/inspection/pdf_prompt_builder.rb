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

      [물건 종류별 판정 규칙]
      - 작업 1에서 추출한 property_type을 작업 2의 모든 판정에 반드시 참조하세요.
      - 각 항목에 applicable_types가 명시된 경우, property_type이 해당 목록에 포함되지 않으면:
        has_risk: null, confidence: "none",
        reasoning: "해당 물건은 [property_type]이므로 이 항목([applicable_types 전용])은 직접 확인이 필요합니다. [AI 의견: 문서에서 확인된 관련 정보가 있다면 기술]"
      - property-006 항목(물건 종류가 아파트인지)은 property_type으로 직접 판정하세요:
        아파트이면 has_risk: false, 아파트가 아니면 has_risk: true.
      - property-007 항목(엘리베이터)은 건물 층수가 4층 미만이면 has_risk: false로 판정하세요.
      - market-006 항목(나홀로 건물)은 property_type이 단독주택이면 has_risk: true로 판정하세요.

      [작업 3: 권리분석]
      등기부등본과 매각물건명세서를 종합하여 권리분석 데이터를 추출하세요.
      금액은 반드시 원(₩) 단위 숫자로 반환하세요.

      - verdict: "safe" | "caution" | "danger" — 낙찰자 입장의 종합 위험도
      - verdict_summary: 한줄 요약 (한국어)
      - base_right_type: 말소기준권리 유형 ("근저당권", "전세권", "가압류", "담보가등기" 등)
      - base_right_holder: 말소기준권리 권리자명
      - base_right_date: 말소기준권리 설정일 (YYYY-MM-DD)
      - opportunity_type: null | "hug_waiver" | "gap_investment" | "occupancy" | "preferred_purchase_risk"
        - "hug_waiver": HUG(주택도시보증공사) 전세보증금반환채권이 설정되어 있으나 권리신고를 포기하여 낙찰자 인수 부담이 없는 경우
        - "gap_investment": 시세 대비 저가 낙찰 가능성이 높은 갭투자 기회 물건
        - "occupancy": 점유 관련 기회 (임차인 자진퇴거 합의 등)
        - "preferred_purchase_risk": 공유자우선매수권 또는 전세사기 특별법 우선매수권 행사 가능성이 있어 낙찰 무산 위험이 있는 물건
      - opportunity_reason: 기회 요인 상세 설명 (없으면 null). HUG 관련 시 등기부에서 확인한 근거를 명시하세요.
      - tenants: 임차인 배열. 각 항목은 { name, deposit(원), move_in_date(YYYY-MM-DD), confirmed_date(YYYY-MM-DD 또는 null, 확정일자), opposing_power(boolean, 참고용 — 서버에서 재계산), priority_rank(정수, 참고용 — 서버에서 재계산), dividend_requested(boolean | null, 배당요구 신청 여부) }
      - 임차인의 dividend_requested는 매각물건명세서 "배당요구일자/배당요구여부" 칼럼을 우선으로 추출하세요. 등기부에는 없으니 명세서가 없는 경우 null 처리합니다.
      - rights_timeline: 권리 설정 내역 배열. 각 항목은 { date(YYYY-MM-DD), type, holder, amount(원), extinguished_on_sale(boolean) }
      - reasoning: 분석 과정과 판단 근거를 단계적으로 서술하세요 (Chain of Thought). 어떤 권리가 말소되고 어떤 권리가 인수되는지 명시적으로 설명하세요.
      - checklist_references: 관련된 점검항목 코드 배열 (예: ["rights-002"])

      [모순 검출 규칙]
      등기부등본과 매각물건명세서를 서로 대조하여 모순(불일치)이 있는지 반드시 확인하세요.
      대표적인 모순 예시:
      - 말소기준권리 유형이 두 문서에서 다름 (예: 등기부는 근저당, 명세서는 가압류)
      - 임차인 정보가 두 문서에서 다름 (보증금, 전입일, 확정일자 등)
      - 권리 설정일자가 두 문서에서 다름
      모순이 발견된 경우:
      - verdict는 반드시 "caution"으로 설정하세요 (모순으로 인해 더 위험하다고 판단되면 "danger" 가능).
      - reasoning에 모순의 구체적 내용을 명시하고, 양쪽 문서에서 무엇이라고 쓰여 있는지 모두 인용하세요.
      - verdict_summary에 "문서 간 불일치 발견" 등 모순을 드러내는 표현을 포함하세요.
      모순이 없는 경우에는 평소대로 판정하세요. 이 규칙이 verdict를 자동으로 강화(약화)시키지 않습니다.

      [응답 형식]
      반드시 아래 JSON 형식으로만 응답하세요.
      - 마크다운 코드 블록(```)으로 감싸지 마세요.
      - JSON 앞뒤에 설명 텍스트를 추가하지 마세요.
      - 응답 전체가 { 로 시작하고 } 로 끝나야 합니다.
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
          "opportunity_type": null | "hug_waiver" | "gap_investment" | "occupancy" | "preferred_purchase_risk",
          "opportunity_reason": null | "...",
          "tenants": [{ "name": "...", "deposit": 0, "move_in_date": "YYYY-MM-DD", "confirmed_date": "YYYY-MM-DD", "opposing_power": true, "priority_rank": 1, "dividend_requested": true }],
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
        applicable = item.applicable_types.present? ? "applicable_types=#{item.applicable_types.join(',')}" : "applicable_types=all"
        "#{item.code}: #{item.question} (yes_means_safe=#{item.yes_means_safe?}, priority=#{item.priority}, #{applicable})"
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
