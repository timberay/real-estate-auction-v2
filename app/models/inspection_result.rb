class InspectionResult < ApplicationRecord
  belongs_to :property
  belongs_to :inspection_item
  belongs_to :user

  enum :source_type, { auto: 0, manual: 1, ai: 2 }

  validates :property_id, uniqueness: { scope: [ :inspection_item_id, :user_id ] }
end
