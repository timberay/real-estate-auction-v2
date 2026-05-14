class InspectionResult < ApplicationRecord
  belongs_to :property
  belongs_to :inspection_item
  belongs_to :user

  has_many :versions, class_name: "InspectionResultVersion", dependent: :destroy

  enum :source_type, { auto: 0, manual: 1, ai: 2 }

  validates :property_id, uniqueness: { scope: [ :inspection_item_id, :user_id ] }

  # Persists a snapshot row to versions. Defaults capture the *current*
  # in-memory attributes; pass overrides to snapshot prior (was-) values
  # from an unsaved record without an extra refetch.
  #
  # T2.7: retries on ActiveRecord::RecordNotUnique to recover from the
  # `next_number = max + 1` race (two concurrent saves can compute the
  # same next_number before either inserts). The DB unique index on
  # (inspection_result_id, version_number) guarantees only one survives;
  # the loser retries with a fresh max read.
  def snapshot_version!(source_type: self.source_type,
                        has_risk: self.has_risk,
                        evidence: self.evidence,
                        resolution_note: self.resolution_note)
    attempts = 0
    begin
      next_number = versions.maximum(:version_number).to_i + 1
      versions.create!(
        version_number: next_number,
        source_type: source_type,
        has_risk: has_risk,
        evidence: evidence,
        resolution_note: resolution_note,
        snapshotted_at: Time.current
      )
    rescue ActiveRecord::RecordNotUnique
      attempts += 1
      retry if attempts < 3
      raise
    end
  end
end
