class EvictionStep < ApplicationRecord
  enum :step_type, { main: 0, branch: 1 }

  validates :code, presence: true, uniqueness: true
  validates :step_type, presence: true
  validates :name, presence: true
  validates :description, presence: true
  validates :position, presence: true

  scope :ordered, -> { order(:position) }
  scope :branches_for, ->(step_code) { branch.where(trigger_step_code: step_code).ordered }

  def branches
    return EvictionStep.none unless main? && branch_codes.present?
    EvictionStep.where(code: branch_codes).ordered
  end
end
