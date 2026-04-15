class EvictionSimulation < ApplicationRecord
  OCCUPANT_TYPES = %w[junior_tenant senior_tenant debtor_owner illegal_occupant].freeze

  OCCUPANT_TYPE_LABELS = {
    "junior_tenant" => "후순위 임차인 (배당 수령)",
    "senior_tenant" => "선순위 임차인 (대항력 有)",
    "debtor_owner" => "채무자 (소유자) 본인",
    "illegal_occupant" => "불법 점유자 / 제3자"
  }.freeze

  BASE_DIFFICULTY = {
    "junior_tenant" => "low",
    "senior_tenant" => "high",
    "debtor_owner" => "medium",
    "illegal_occupant" => "high"
  }.freeze

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

  def valid_occupant_type?
    occupant_type.nil? || OCCUPANT_TYPES.include?(occupant_type)
  end

  def occupant_type_label
    OCCUPANT_TYPE_LABELS[occupant_type]
  end

  def base_difficulty
    BASE_DIFFICULTY[occupant_type]
  end
end
