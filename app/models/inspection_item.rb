class InspectionItem < ApplicationRecord
  has_many :inspection_results, dependent: :destroy

  enum :tab, {
    sale_document: 0,   # 매각물건명세서
    registry: 1,        # 등기부등본
    building_ledger: 2, # 건축물대장
    online: 3,          # 온라인조회
    field_visit: 4,     # 현장임장
    etc: 5              # 기타
  }

  validates :code, presence: true, uniqueness: true
  validates :tab, presence: true
  validates :question, presence: true
  validates :category, presence: true

  scope :ordered, -> { order(:tab, :tab_position) }
  scope :for_tab, ->(tab) { where(tab: tab).order(:tab_position) }
end
