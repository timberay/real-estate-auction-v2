class InspectionRatingService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    results = @property.inspection_results.where(user: @user)

    if results.exists?(has_risk: nil)
      return :incomplete
    end

    risk_results = results.where(has_risk: true)

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
    return :incomplete if results.exists?(has_risk: nil)

    risk_results = results.where(has_risk: true)

    if risk_results.exists?(resolvable: false)
      :danger
    elsif risk_results.any?
      :caution
    else
      :safe
    end
  end
end
