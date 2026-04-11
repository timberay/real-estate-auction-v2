class AuctionSchedule < ApplicationRecord
  belongs_to :property

  validates :schedule_date, presence: true
  validates :min_price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
end
