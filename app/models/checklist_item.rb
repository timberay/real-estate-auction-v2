class ChecklistItem < ApplicationRecord
  enum :risk_axis, { legal: 0, resale: 1, loan: 2 }

  validates :code, presence: true, uniqueness: true
  validates :question, presence: true
  validates :category, presence: true
  validates :risk_axis, presence: true

  scope :ordered, -> { order(:position) }
end
