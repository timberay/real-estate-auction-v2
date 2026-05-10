class InspectionResultVersion < ApplicationRecord
  belongs_to :inspection_result

  enum :source_type, { auto: 0, manual: 1, ai: 2 }

  validates :version_number, presence: true, numericality: { greater_than: 0 }
end
