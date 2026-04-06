class RightsAnalysisReport < ApplicationRecord
  belongs_to :user
  belongs_to :property

  enum :verdict, { safe: 0, caution: 1, danger: 2 }

  validates :user_id, uniqueness: { scope: :property_id }
  validates :analyzed_at, presence: true
end
