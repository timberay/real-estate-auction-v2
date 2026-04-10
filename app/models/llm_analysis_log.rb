class LlmAnalysisLog < ApplicationRecord
  belongs_to :property
  belongs_to :user, optional: true

  enum :status, { pending: 0, completed: 1, failed: 2 }

  validates :system_prompt, presence: true
  validates :user_prompt, presence: true

  def self.latest_for(property)
    where(property: property, status: :completed)
      .order(executed_at: :desc)
      .first
  end
end
