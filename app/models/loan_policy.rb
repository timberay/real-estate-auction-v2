class LoanPolicy < ApplicationRecord
  has_many :budget_settings, dependent: :nullify
  belongs_to :property_type
  validates :policy_name, presence: true
  validates :loan_ratio, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :effective_date, presence: true
  scope :active, -> {
    where(enabled: true).where("expiry_date IS NULL OR expiry_date >= ?", Date.current)
  }
  scope :for_property_type, ->(property_type_id) {
    where(property_type_id: property_type_id)
  }
end
