class LlmAnalysisLog < ApplicationRecord
  belongs_to :property
  belongs_to :user, optional: true

  serialize :response_json, coder: JSON
  encrypts :system_prompt
  encrypts :user_prompt
  encrypts :response_json

  enum :status, { pending: 0, completed: 1, failed: 2 }

  STATUS_LABELS = {
    "pending" => "진행 중",
    "completed" => "완료",
    "failed" => "실패"
  }.freeze

  validates :system_prompt, presence: true
  validates :user_prompt, presence: true

  def self.latest_for(property)
    where(property: property, status: :completed)
      .order(executed_at: :desc)
      .first
  end

  def status_label
    STATUS_LABELS.fetch(status, status.to_s)
  end
end
