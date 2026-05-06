class TabSummaryTableComponent < ViewComponent::Base
  TAB_LABELS = {
    "rights_analysis" => "권리분석",
    "profit_analysis" => "수익분석",
    "field_check" => "현장확인",
    "bidding" => "입찰&낙찰"
  }.freeze

  def initialize(results_by_tab:, property:)
    @results_by_tab = results_by_tab
    @property = property
  end

  private

  def rows
    TAB_LABELS.map do |key, label|
      results = @results_by_tab[key] || []
      { key: key, label: label, safe: results.count { |r| r.has_risk == false }, risk: results.count { |r| r.has_risk == true }, unanswered: results.count { |r| r.has_risk.nil? } }
    end
  end
end
