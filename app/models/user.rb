class User < ApplicationRecord
  before_validation :assign_guest_token, on: :create

  has_one :budget_setting, dependent: :destroy, merge_policy: :prefer_guest

  has_many :user_properties, dependent: :destroy,
           merge_policy: :prefer_guest, natural_key: :property_id
  has_many :properties, through: :user_properties
  has_many :inspection_results, dependent: :destroy,
           merge_policy: :prefer_guest, natural_key: [ :property_id, :inspection_item_id ]
  has_many :rights_analysis_reports, dependent: :destroy,
           merge_policy: :prefer_guest, natural_key: :property_id
  has_many :api_credentials, dependent: :destroy,
           merge_policy: :keep_target, natural_key: :provider_name
  has_many :search_results, dependent: :destroy,
           merge_policy: :prefer_guest, natural_key: :case_number
  has_many :llm_analysis_logs, dependent: :nullify

  def self.mergeable_reflections
    reflect_on_all_associations.select { |r| r.options[:merge_policy].present? }
  end

  # -- Search preference convenience methods --

  def preferred_property_type_code
    budget_setting&.property_type&.code
  end

  def preferred_area_range
    bs = budget_setting
    return nil unless bs&.area_range_min && bs&.area_range_max

    { min: bs.area_range_min, max: bs.area_range_max }
  end

  def preferred_area_category
    budget_setting&.selected_area_category
  end

  private

  def assign_guest_token
    return unless guest?
    return if guest_token.present?

    self.guest_token = SecureRandom.urlsafe_base64(32)
  end
end
