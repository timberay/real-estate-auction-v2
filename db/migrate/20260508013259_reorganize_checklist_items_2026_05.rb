class ReorganizeChecklistItems202605 < ActiveRecord::Migration[8.0]
  CHANGES = [
    { code: "inspect-005", attrs: { tab: "field_check" } },
    { code: "inspect-009", attrs: { question: "현장 방문(임장)을 통해 부동산으로부터 매도 가능 정보를 얻었습니까?" } },
    { code: "eviction-001", attrs: { category: "현장조사&서류검증" } },
    { code: "manual-001", attrs: { tab: "rights_analysis" } }
  ].freeze

  DELETIONS = %w[tax-007 exit-002].freeze

  def up
    ActiveRecord::Base.transaction do
      CHANGES.each do |change|
        item = InspectionItem.find_by(code: change[:code])
        next unless item
        item.update!(change[:attrs])
      end

      DELETIONS.each do |code|
        InspectionItem.find_by(code: code)&.destroy
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
