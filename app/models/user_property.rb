class UserProperty < ApplicationRecord
  belongs_to :user
  belongs_to :property
  enum :safety_rating, { safe: 0, caution: 1, danger: 2 }
  validates :user_id, uniqueness: { scope: :property_id }
end
