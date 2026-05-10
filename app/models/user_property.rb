class UserProperty < ApplicationRecord
  belongs_to :user
  belongs_to :property
  enum :safety_rating, { safe: 0, caution: 1, danger: 2 }
  validates :user_id, uniqueness: { scope: :property_id }

  has_many_attached :photos

  validate :photos_must_be_images

  scope :ordered_for_list, -> { order(favorite: :desc, created_at: :desc) }

  private

  def photos_must_be_images
    photos.each do |photo|
      unless photo.content_type&.start_with?("image/")
        errors.add(:photos, "이미지 파일만 업로드할 수 있습니다.")
      end
    end
  end
end
