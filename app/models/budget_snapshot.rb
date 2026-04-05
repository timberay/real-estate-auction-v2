class BudgetSnapshot < ApplicationRecord
  TRIGGERS = %w[onboarding manual_edit recalculate].freeze
  belongs_to :user
  belongs_to :parent_snapshot, class_name: "BudgetSnapshot", optional: true
  has_many :child_snapshots, class_name: "BudgetSnapshot", foreign_key: :parent_snapshot_id, dependent: :nullify
  validates :version, presence: true, numericality: { greater_than: 0 }
  validates :trigger, inclusion: { in: TRIGGERS }
  validates :calculated_at, presence: true
  scope :for_user, ->(user_id) { where(user_id: user_id).order(version: :desc) }

  def self.next_version_for(user_id)
    where(user_id: user_id).maximum(:version).to_i + 1
  end
end
