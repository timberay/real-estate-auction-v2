class InspectionRatingService
  ANALYSIS_TABS = %w[rights_analysis property_analysis profit_analysis field_check bidding].freeze

  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    results = @property.inspection_results.where(user: @user)
    answered = results.where.not(has_risk: nil)

    return :incomplete if answered.empty?

    risk_results = answered.where(has_risk: true)

    rating = if risk_results.exists?(resolvable: false)
      :danger
    elsif risk_results.any?
      :caution
    else
      :safe
    end

    user_property = UserProperty.find_by!(user: @user, property: @property)
    user_property.update!(safety_rating: rating, analyzed_at: Time.current)
    rating
  end

  def tab_rating(tab_key)
    tab_int = InspectionItem.tabs[tab_key]
    results = @property.inspection_results
      .joins(:inspection_item)
      .where(inspection_items: { tab: tab_int }, user: @user)

    return nil if results.empty?

    answered = results.where.not(has_risk: nil)
    return :incomplete if answered.empty?

    risk_results = answered.where(has_risk: true)

    if risk_results.exists?(resolvable: false)
      :danger
    elsif risk_results.any?
      :caution
    else
      :safe
    end
  end

  def fully_evaluated?
    results = @property.inspection_results.where(user: @user)
    results.any? && results.where(has_risk: nil).none?
  end

  def tabs_evaluated_count
    evaluated = ANALYSIS_TABS.count do |tab_key|
      rating = tab_rating(tab_key)
      rating && rating != :incomplete
    end
    [ evaluated, ANALYSIS_TABS.size ]
  end
end
