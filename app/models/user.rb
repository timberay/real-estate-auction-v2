class User < ApplicationRecord
  has_secure_password
  has_one :budget_setting, dependent: :destroy
  has_many :budget_snapshots, dependent: :destroy
  has_many :user_properties, dependent: :destroy
  has_many :properties, through: :user_properties
  has_many :property_check_results, dependent: :destroy
  has_many :rights_analysis_reports, dependent: :destroy
  validates :email, presence: true, uniqueness: true
end
