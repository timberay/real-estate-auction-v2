class InspectionRatingService
  ANALYSIS_TABS = %w[rights_analysis profit_analysis field_check bidding].freeze

  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    rating = overall_rating
    return rating if rating == :incomplete

    user_property = UserProperty.find_by!(user: @user, property: @property)
    user_property.update!(safety_rating: rating, analyzed_at: Time.current)
    rating
  end

  def overall_rating
    answered = visible_results.select { |r| !r.has_risk.nil? }
    return :incomplete if answered.empty?

    risk_results = answered.select { |r| r.has_risk }

    if risk_results.any? { |r| r.resolvable == false }
      :danger
    elsif risk_results.any?
      :caution
    else
      :safe
    end
  end

  def tab_rating(tab_key)
    visible = visible_results.select { |r| r.inspection_item.tab == tab_key }
    return nil if visible.empty?

    answered = visible.select { |r| !r.has_risk.nil? }
    return :incomplete if answered.empty?

    risk_results = answered.select { |r| r.has_risk }

    if risk_results.any? { |r| r.resolvable == false }
      :danger
    elsif risk_results.any?
      :caution
    else
      :safe
    end
  end

  def fully_evaluated?
    visible_results.any? && visible_results.all? { |r| !r.has_risk.nil? }
  end

  def tabs_evaluated_count
    evaluated = ANALYSIS_TABS.count do |tab_key|
      rating = tab_rating(tab_key)
      rating && rating != :incomplete
    end
    [ evaluated, ANALYSIS_TABS.size ]
  end

  private

  def visible_results
    @visible_results ||= begin
      all_results = @property.inspection_results.where(user: @user).includes(:inspection_item)
      answered_context = all_results.index_by { |r| r.inspection_item.code }
      all_items_by_code = all_results.map(&:inspection_item).index_by(&:code)
      property_type = @property.property_type

      all_results.select do |r|
        r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context, all_items_by_code: all_items_by_code)
      end
    end
  end
end
