class Notification < ApplicationRecord
  belongs_to :user

  validates :kind, :title, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :ordered_recent, -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def mark_read!
    return if read?
    update!(read_at: Time.current)
  end
end
