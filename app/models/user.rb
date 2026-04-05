class User < ApplicationRecord
  has_secure_password
  has_one :budget_setting, dependent: :destroy
  has_many :budget_snapshots, dependent: :destroy
  validates :email, presence: true, uniqueness: true
end
