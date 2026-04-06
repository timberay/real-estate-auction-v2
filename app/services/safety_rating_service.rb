class SafetyRatingService
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    results = @property.property_check_results.where(has_risk: true, user: @user)

    rating = if results.exists?(resolvable: false)
      :danger
    elsif results.any?
      :caution
    else
      :safe
    end

    user_property = UserProperty.find_by!(user: @user, property: @property)
    user_property.update!(safety_rating: rating, analyzed_at: Time.current)
    rating
  end
end
