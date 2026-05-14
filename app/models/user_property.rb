class UserProperty < ApplicationRecord
  belongs_to :user
  belongs_to :property
  enum :safety_rating, { safe: 0, caution: 1, danger: 2 }
  validates :user_id, uniqueness: { scope: :property_id }

  has_many_attached :photos

  REJECTED_IMAGE_TYPES = %w[image/svg+xml image/x-icon].freeze
  MAX_PHOTO_SIZE = 10.megabytes

  validate :photos_must_be_images

  scope :ordered_for_list, -> { order(favorite: :desc, created_at: :desc) }

  EVICTION_WINDOW = 6.months

  def eviction_deadline
    return nil unless payment_completed_on
    payment_completed_on + EVICTION_WINDOW
  end

  def days_to_eviction_deadline
    return nil unless eviction_deadline
    (eviction_deadline - Date.current).to_i
  end

  def estimated_deposit
    return nil unless property&.min_bid_price.to_i.positive?
    (property.min_bid_price * deposit_rate).to_i
  end

  def shared_ownership?
    property&.property_count.to_i > 1
  end

  private

  def photos_must_be_images
    photos.each do |photo|
      if !photo.content_type&.start_with?("image/")
        errors.add(:photos, "이미지 파일만 업로드할 수 있습니다.")
      elsif REJECTED_IMAGE_TYPES.include?(photo.content_type)
        errors.add(:photos, "지원하지 않는 이미지 형식입니다. (SVG/ICO 제외)")
      elsif photo.byte_size > MAX_PHOTO_SIZE
        errors.add(:photos, "파일 크기는 10MB 이하로 업로드해 주세요.")
      end
    end
  end
end
