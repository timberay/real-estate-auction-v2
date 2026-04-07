class PropertyType < ApplicationRecord
  has_many :budget_settings, dependent: :nullify
  has_many :reserve_fund_defaults, dependent: :destroy
  has_many :loan_policies, dependent: :destroy
  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  scope :enabled, -> { where(enabled: true) }
  scope :ordered, -> { order(:sort_order) }
end
