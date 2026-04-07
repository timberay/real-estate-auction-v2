class TabSummaryTableComponent < ViewComponent::Base
  TAB_LABELS = {
    "sale_document" => "매각물건명세서",
    "registry" => "등기부등본",
    "building_ledger" => "건축물대장",
    "online" => "온라인조회",
    "field_visit" => "현장임장",
    "etc" => "기타"
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
