class SafetyRatingService
  def self.call(property:)
    new(property:).call
  end

  def initialize(property:)
    @property = property
  end

  def call
    results = @property.property_check_results.where(has_risk: true)

    rating = if results.exists?(resolvable: false)
      :danger
    elsif results.any?
      :caution
    else
      :safe
    end

    @property.update!(safety_rating: rating)
    rating
  end
end
