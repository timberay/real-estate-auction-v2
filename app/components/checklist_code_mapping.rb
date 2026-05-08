module ChecklistCodeMapping
  extend ActiveSupport::Concern

  def build_checklist_refs(codes)
    codes = Array(codes).compact
    return [] if codes.empty?

    question_map = InspectionItem.where(code: codes).pluck(:code, :question).to_h
    codes.map { |code| { code: code, question: question_map[code] } }
  end
end
