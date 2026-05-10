class InspectionResult < ApplicationRecord
  belongs_to :property
  belongs_to :inspection_item
  belongs_to :user

  has_many :versions, class_name: "InspectionResultVersion", dependent: :destroy

  enum :source_type, { auto: 0, manual: 1, ai: 2 }

  validates :property_id, uniqueness: { scope: [ :inspection_item_id, :user_id ] }

  # Persists the current attributes as the next InspectionResultVersion row.
  # Used to preserve prior AI judgment + evidence + reasoning before an
  # overwrite (see Inspection::InspectionResultMapper).
  def snapshot_version!
    next_number = versions.maximum(:version_number).to_i + 1
    versions.create!(
      version_number: next_number,
      source_type: source_type,
      has_risk: has_risk,
      evidence: evidence,
      resolution_note: resolution_note,
      snapshotted_at: Time.current
    )
  end
end
