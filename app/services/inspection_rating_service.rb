class InspectionRatingService
  ANALYSIS_TABS = %w[rights_analysis profit_analysis field_check bidding].freeze
  # Coverage requirement for the :safe rating gate.
  # Uses VISIBLE priority='상' items (not all). Items with depends_on whose parent
  # has no risk are hidden — they are "not applicable" in this context, so blocking
  # :safe on them would be a false gate. (Audit Exp#13/#14, Task A7.)
  REQUIRED_COVERAGE = 1.0

  def self.call(property:, user:)
    new(property:, user:).call
  end

  # Pre-loads InspectionItem reference data once. Pass the returned hash via
  # item_cache: when computing ratings for many properties in one request
  # (e.g. comparison page) — avoids re-scanning inspection_items per call.
  def self.build_item_cache
    items = InspectionItem.all.to_a
    {
      by_code: items.index_by(&:code),
      high_priority: items.select { |i| i.priority == "상" }
    }
  end

  def initialize(property:, user:, item_cache: nil)
    @property = property
    @user = user
    @item_cache = item_cache
  end

  def call
    rating = overall_rating
    return rating if rating == :incomplete

    user_property = UserProperty.find_by!(user: @user, property: @property)
    user_property.update!(safety_rating: rating, analyzed_at: Time.current)
    rating
  end

  def overall_rating
    return :incomplete if priority_high_coverage < REQUIRED_COVERAGE

    answered = visible_results.select { |r| !r.has_risk.nil? }
    return :incomplete if answered.empty?

    risk_results = answered.select { |r| r.has_risk }

    if risk_results.any? { |r| r.resolvable != true }
      :danger
    elsif risk_results.any?
      :caution
    else
      :safe
    end
  end

  def unanswered_high_priority_count
    visible_high_items.size - answered_high_count
  end

  def tab_rating(tab_key)
    visible = visible_results.select { |r| r.inspection_item.tab == tab_key }
    return nil if visible.empty?

    answered = visible.select { |r| !r.has_risk.nil? }
    return :incomplete if answered.empty?

    risk_results = answered.select { |r| r.has_risk }

    if risk_results.any? { |r| r.resolvable != true }
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

  def priority_high_coverage
    total = visible_high_items.size
    return 1.0 if total == 0
    answered_high_count.to_f / total
  end

  def visible_high_items
    @visible_high_items ||= begin
      all_results = @property.inspection_results.where(user: @user).includes(:inspection_item)
      answered_context = all_results.index_by { |r| r.inspection_item.code }
      all_items_by_code = items_by_code
      property_type = @property.property_type

      high_priority_items.select do |item|
        item.visible_for?(property_type: property_type, answered_results: answered_context, all_items_by_code: all_items_by_code)
      end
    end
  end

  def items_by_code
    @item_cache&.dig(:by_code) || InspectionItem.all.index_by(&:code)
  end

  def high_priority_items
    @item_cache&.dig(:high_priority) || InspectionItem.where(priority: "상").to_a
  end

  def answered_high_count
    @answered_high_count ||= begin
      return 0 if visible_high_items.empty?
      @property.inspection_results
        .where(user: @user)
        .where(inspection_item: visible_high_items)
        .where.not(has_risk: nil)
        .count
    end
  end

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
