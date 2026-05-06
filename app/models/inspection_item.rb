class InspectionItem < ApplicationRecord
  has_many :inspection_results, dependent: :destroy

  enum :tab, {
    rights_analysis: 0, # 권리분석
    profit_analysis: 2, # 수익분석
    field_check: 3,     # 현장확인
    bidding: 4          # 입찰&낙찰
  }

  ANSWER_TYPES = %w[action_confirm].freeze

  validates :code, presence: true, uniqueness: true
  validates :tab, presence: true
  validates :question, presence: true
  validates :category, presence: true
  validates :answer_type, inclusion: { in: ANSWER_TYPES }, allow_nil: true

  scope :ordered, -> { order(:tab, :tab_position) }
  scope :for_tab, ->(tab) { where(tab: tab).order(:tab_position) }
  scope :applicable_for_type, ->(property_type) {
    return all if property_type.blank?
    where("applicable_types IS NULL OR EXISTS (SELECT 1 FROM json_each(applicable_types) WHERE json_each.value = ?)", property_type)
  }

  def applicable_for?(property_type)
    applicable_types.blank? || applicable_types.include?(property_type)
  end

  def visible_for?(property_type:, answered_results: {}, all_items_by_code: {})
    applicable_for?(property_type) &&
      !skip_for?(answered_results, all_items_by_code: all_items_by_code)
  end

  def depends_on
    val = super
    val.is_a?(String) ? JSON.parse(val) : val
  end

  def skip_for?(answered_results_by_code, all_items_by_code: {}, visited: Set.new)
    return false if depends_on.blank?
    return true if visited.include?(code)

    parent_code = depends_on["code"]
    parent_item = all_items_by_code[parent_code]

    if parent_item&.skip_for?(answered_results_by_code, all_items_by_code: all_items_by_code, visited: visited | [ code ])
      return true
    end

    parent_result = answered_results_by_code[parent_code]
    return true if parent_result.nil? || parent_result.has_risk.nil?

    parent_result.has_risk != depends_on["show_when_risk"]
  end
end
