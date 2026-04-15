class EvictionSimulatorQuestion < ApplicationRecord
  enum :phase, { summary: 0, detail: 1 }

  validates :code, presence: true, uniqueness: true
  validates :phase, presence: true
  validates :step_code, presence: true
  validates :question, presence: true

  scope :ordered, -> { order(:id) }
  scope :for_occupant_type, ->(type) { where(occupant_type: type) }

  def step
    EvictionStep.find_by(code: step_code)
  end
end
