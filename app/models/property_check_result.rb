class PropertyCheckResult < ApplicationRecord
  belongs_to :property
  belongs_to :checklist_item

  enum :source_type, { auto: 0, manual: 1 }

  validates :property_id, uniqueness: { scope: :checklist_item_id }
end
