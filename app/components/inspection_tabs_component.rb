class InspectionTabsComponent < ViewComponent::Base
  TAB_CONFIG = [
    { key: "rights_analysis", label: "권리분석" },
    { key: "profit_analysis", label: "수익분석" },
    { key: "field_check",     label: "현장확인" },
    { key: "bidding",         label: "입찰&낙찰" },
    { key: "grade",           label: "종합 판정" }
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
    overall = rating_service.overall_rating
    fully = rating_service.fully_evaluated?
    TAB_CONFIG.map do |tab|
      stats = @tab_stats[tab[:key]] || { checked: 0, total: 0 }
      tab.merge(
        active: tab[:key] == @active_tab,
        url: tab_url(tab[:key]),
        checked: stats[:checked],
        total: stats[:total],
        rating: tab[:key] == "grade" ? overall : rating_service.tab_rating(tab[:key]),
        partial: tab[:key] == "grade" && !fully && overall != :incomplete
      )
    end
  end

  def load_tab_stats
    all_results = @property.inspection_results
      .where(user: @user)
      .includes(:inspection_item)
    answered_context = all_results.index_by { |r| r.inspection_item.code }
    all_items_by_code = all_results.map(&:inspection_item).index_by(&:code)
    property_type = @property.property_type

    visible = all_results.select do |r|
      r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context, all_items_by_code: all_items_by_code)
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

  GRADE_BUTTON_CLASSES = {
    safe: {
      active: "bg-green-600 text-white dark:bg-green-500",
      inactive: "bg-green-100 text-green-800 hover:bg-green-200 dark:bg-green-900/30 dark:text-green-300 dark:hover:bg-green-900/50"
    },
    caution: {
      active: "bg-yellow-500 text-white dark:bg-yellow-500",
      inactive: "bg-yellow-100 text-yellow-800 hover:bg-yellow-200 dark:bg-yellow-900/30 dark:text-yellow-300 dark:hover:bg-yellow-900/50"
    },
    danger: {
      active: "bg-red-600 text-white dark:bg-red-500",
      inactive: "bg-red-100 text-red-800 hover:bg-red-200 dark:bg-red-900/30 dark:text-red-300 dark:hover:bg-red-900/50"
    }
  }.freeze

  GRADE_DEFAULT_CLASSES = {
    active: "bg-blue-600 text-white dark:bg-blue-500",
    inactive: "bg-slate-100 text-slate-700 hover:bg-slate-200 hover:text-slate-900 dark:bg-slate-800 dark:text-slate-300 dark:hover:bg-slate-700 dark:hover:text-slate-100"
  }.freeze

  def rating_badge(rating)
    RATING_BADGE[rating]
  end

  def grade_button_classes(tab)
    palette = GRADE_BUTTON_CLASSES[tab[:rating]] || GRADE_DEFAULT_CLASSES
    palette[tab[:active] ? :active : :inactive]
  end
end
