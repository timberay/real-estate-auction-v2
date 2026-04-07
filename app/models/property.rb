class Property < ApplicationRecord
  has_many :user_properties, dependent: :destroy
  has_many :users, through: :user_properties
  has_many :inspection_results, dependent: :destroy
  has_many :inspection_items, through: :inspection_results
  has_many :rights_analysis_reports, dependent: :destroy
  validates :case_number, presence: true, uniqueness: true
end
