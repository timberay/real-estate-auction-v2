class Property < ApplicationRecord
  belongs_to :user, optional: true

  enum :safety_rating, { safe: 0, caution: 1, danger: 2 }

  validates :case_number, presence: true, uniqueness: true
end
