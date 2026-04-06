class Property < ApplicationRecord
  has_many :user_properties, dependent: :destroy
  has_many :users, through: :user_properties
  has_many :property_check_results, dependent: :destroy
  has_many :checklist_items, through: :property_check_results
  validates :case_number, presence: true, uniqueness: true
end
