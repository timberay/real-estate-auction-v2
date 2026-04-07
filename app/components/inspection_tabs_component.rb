class InspectionTabsComponent < ViewComponent::Base
  TAB_CONFIG = [
    { key: "sale_document", label: "매각물건명세서" },
    { key: "registry",      label: "등기부등본" },
    { key: "building_ledger", label: "건축물대장" },
    { key: "online",        label: "온라인조회" },
    { key: "field_visit",   label: "현장임장" },
    { key: "etc",           label: "기타" },
    { key: "grade",         label: "최종등급" }
  ].freeze

  def initialize(property:, user:, active_tab:)
    @property = property
    @user = user
    @active_tab = active_tab
  end

  private

  def tabs
    TAB_CONFIG.map do |tab|
      counts = tab_counts(tab[:key])
      tab.merge(
        active: tab[:key] == @active_tab,
        url: tab_url(tab[:key]),
        checked: counts[:checked],
        total: counts[:total]
      )
    end
  end

  def tab_counts(key)
    return { checked: 0, total: 0 } if key == "grade"
    tab_int = InspectionItem.tabs[key]
    return { checked: 0, total: 0 } unless tab_int

    results = @property.inspection_results
      .joins(:inspection_item)
      .where(inspection_items: { tab: tab_int }, user: @user)

    { checked: results.where.not(has_risk: nil).count, total: results.count }
  end

  def tab_url(key)
    if key == "grade"
      helpers.property_inspections_grade_path(@property)
    else
      helpers.edit_property_inspections_tab_path(@property, tab_key: key)
    end
  end
end
