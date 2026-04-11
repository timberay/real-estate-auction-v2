class InspectionItem < ApplicationRecord
  has_many :inspection_results, dependent: :destroy

  enum :tab, {
    rights_analysis: 0,   # 권리분석
    property_analysis: 1, # 물건분석
    profit_analysis: 2,   # 수익분석
    field_check: 3,       # 현장확인
    bidding: 4            # 입찰&낙찰
  }

  ANSWER_TYPES = %w[action_confirm].freeze

  validates :code, presence: true, uniqueness: true
  validates :tab, presence: true
  validates :question, presence: true
  validates :category, presence: true
  validates :answer_type, inclusion: { in: ANSWER_TYPES }, allow_nil: true

  scope :ordered, -> { order(:tab, :tab_position) }
  scope :for_tab, ->(tab) { where(tab: tab).order(:tab_position) }

  def applicable_for?(property_type)
    applicable_types.blank? || applicable_types.include?(property_type)
  end
end
