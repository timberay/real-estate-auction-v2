class Property < ApplicationRecord
  belongs_to :user, optional: true
  has_many :property_check_results, dependent: :destroy
  has_many :checklist_items, through: :property_check_results

  enum :safety_rating, { safe: 0, caution: 1, danger: 2 }

  validates :case_number, presence: true, uniqueness: true
end
