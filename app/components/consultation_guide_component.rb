class ConsultationGuideComponent < ViewComponent::Base
  PROFESSIONALS = {
    "rights_analysis" => { title: "법무사/변호사", scope: "등기 권리관계 확인 및 인수 여부 판단" },
    "profit_analysis" => { title: "세무사 + 은행/대출 컨설턴트", scope: "취득세, 양도세 계산 및 대출 가능 여부 확인" },
    "field_check" => { title: "공인중개사", scope: "현장 상태 확인 및 시세 검증" },
    "bidding" => { title: "법무사", scope: "입찰 절차 및 보증금 관련 확인" }
  }.freeze

  def initialize(risk_results:, show_title: true)
    @risk_results = risk_results
    @show_title = show_title
  end

  def render?
    @risk_results.any?
  end

  private

  def grouped_recommendations
    @risk_results
      .group_by { |r| r.inspection_item.tab }
      .filter_map do |tab, results|
        prof = PROFESSIONALS[tab]
        next unless prof
        { professional: prof, items: results }
      end
  end
end
