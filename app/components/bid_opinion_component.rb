class BidOpinionComponent < ViewComponent::Base
  def initialize(risk_count:, opportunity_count:)
    @risk_count = risk_count
    @opportunity_count = opportunity_count
  end

  def headline
    "위험 항목 #{@risk_count}건 · 기회 항목 #{@opportunity_count}건"
  end

  def disclaimer
    "본 도구는 권리분석 보조이며 입찰 권유가 아닙니다. 모든 투자 결정의 책임은 사용자에게 있습니다."
  end
end
