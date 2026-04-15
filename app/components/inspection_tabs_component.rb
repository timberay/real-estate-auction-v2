class InspectionTabsComponent < ViewComponent::Base
  TAB_CONFIG = [
    { key: "rights_analysis",   label: "권리분석" },
    { key: "property_analysis", label: "물건분석" },
    { key: "profit_analysis",   label: "수익분석" },
    { key: "field_check",       label: "현장확인" },
    { key: "bidding",           label: "입찰&낙찰" },
    { key: "grade",             label: "종합 판정" }
  ].freeze

  def initialize(property:, user:, active_tab:)
    @property = property
    @user = user
    @active_tab = active_tab
    @tab_stats = load_tab_stats
  end

  private

  def tabs
    rating_service = InspectionRatingService.new(property: @property, user: @user)
    TAB_CONFIG.map do |tab|
      stats = @tab_stats[tab[:key]] || { checked: 0, total: 0 }
      tab.merge(
        active: tab[:key] == @active_tab,
        url: tab_url(tab[:key]),
        checked: stats[:checked],
        total: stats[:total],
        rating: tab[:key] == "grade" ? nil : rating_service.tab_rating(tab[:key])
      )
    end
  end

  def load_tab_stats
    all_results = @property.inspection_results
      .where(user: @user)
      .includes(:inspection_item)
    answered_context = all_results.index_by { |r| r.inspection_item.code }
    property_type = @property.property_type

    visible = all_results.select do |r|
      r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context)
    end

    visible.group_by { |r| r.inspection_item.tab }.each_with_object({}) do |(tab_key, results_in_tab), hash|
      hash[tab_key] = {
        checked: results_in_tab.count { |r| !r.has_risk.nil? },
        total: results_in_tab.size
      }
    end
  end

  def tab_url(key)
    if key == "grade"
      helpers.property_inspections_grade_path(@property)
    else
      helpers.edit_property_inspections_tab_path(@property, tab_key: key)
    end
  end

  RATING_BADGE = {
    safe: { label: "안전", classes: "bg-green-200 text-green-800 dark:bg-green-900/40 dark:text-green-300" },
    caution: { label: "주의", classes: "bg-yellow-200 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-300" },
    danger: { label: "경고", classes: "bg-red-200 text-red-800 dark:bg-red-900/40 dark:text-red-300" }
  }.freeze

  def rating_badge(rating)
    RATING_BADGE[rating]
  end
end
