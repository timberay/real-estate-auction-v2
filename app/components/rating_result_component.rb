# frozen_string_literal: true

class RatingResultComponent < ViewComponent::Base
  RATING_CONFIG = {
    "safe" => { color: "text-green-700 dark:text-green-400", bg: "bg-green-50 dark:bg-green-900/20", label: "안전", description: "위험 항목이 없습니다" },
    "caution" => { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-50 dark:bg-yellow-900/20", label: "주의", description: "위험 항목이 있으나 모두 해결 가능합니다" },
    "danger" => { color: "text-red-700 dark:text-red-400", bg: "bg-red-50 dark:bg-red-900/20", label: "경고", description: "해결 불가능한 위험 항목이 있습니다" }
  }.freeze

  def initialize(property:, risk_results:, rating: nil, label: nil)
    @property = property
    @risk_results = risk_results
    @label = label
    @config = RATING_CONFIG[rating.to_s] || RATING_CONFIG["safe"]
  end
end
