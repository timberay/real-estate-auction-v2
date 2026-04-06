class PropertyTabsComponent < ViewComponent::Base
  TABS = [
    { key: :info, number: "①", label: "기본 정보" },
    { key: :checklist, number: "②", label: "체크리스트" },
    { key: :report, number: "③", label: "권리 분석" },
    { key: :rating, number: "④", label: "등급 산정" }
  ].freeze

  def initialize(property:, user:, active_tab:)
    @property = property
    @user = user
    @active_tab = active_tab
  end

  private

  def tabs
    TABS.map do |tab|
      tab.merge(
        active: tab[:key] == @active_tab,
        completed: tab_completed?(tab[:key]),
        url: tab_url(tab[:key])
      )
    end
  end

  def tab_completed?(key)
    case key
    when :info then true
    when :checklist then user_property&.analyzed_at.present?
    when :report then report.present?
    when :rating then user_property&.safety_rating.present?
    end
  end

  def tab_url(key)
    case key
    when :info then helpers.property_path(@property)
    when :checklist then helpers.edit_property_analyses_checklist_path(@property)
    when :report then helpers.property_analyses_report_path(@property)
    when :rating then helpers.property_analyses_rating_path(@property)
    end
  end

  def user_property
    @user_property ||= UserProperty.find_by(user: @user, property: @property)
  end

  def report
    @report ||= RightsAnalysisReport.find_by(user: @user, property: @property)
  end
end
