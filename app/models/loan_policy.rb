class LoanPolicy < ApplicationRecord
  REGULATED_REGIONS = [ "서울특별시" ].freeze

  has_many :budget_settings, dependent: :nullify
  belongs_to :property_type
  validates :policy_name, presence: true
  validates :loan_ratio, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :regulated_loan_ratio, presence: true,
            numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :effective_date, presence: true
  scope :active, -> {
    where(enabled: true).where("expiry_date IS NULL OR expiry_date >= ?", Date.current)
  }
  scope :for_property_type, ->(property_type_id) {
    where(property_type_id: property_type_id)
  }

  def ratio_for(region)
    REGULATED_REGIONS.include?(region) ? regulated_loan_ratio : loan_ratio
  end
end
