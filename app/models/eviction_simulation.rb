class EvictionSimulation < ApplicationRecord
  belongs_to :property, optional: true

  validates :property_id, uniqueness: true, allow_nil: true

  scope :stale, -> {
    where(property_id: nil)
      .where(created_at: ...24.hours.ago)
  }

  def record_answer(question_code, value)
    self.answers ||= {}
    self.answers[question_code] = value
  end

  def answer_for(question_code)
    answers&.dig(question_code)
  end

  def property_linked?
    property_id.present?
  end
end
