module ChecklistCodeMapping
  module_function

  # Maps checklist codes to question text via a single DB query.
  # Returns an array of { code:, question: } hashes in input order.
  # Codes not found in the DB are returned with question: nil
  # (UI renders "(삭제된 항목)" for these).
  def build_checklist_refs(codes)
    codes = Array(codes).compact
    return [] if codes.empty?

    question_map = InspectionItem.where(code: codes).pluck(:code, :question).to_h
    codes.map { |code| { code: code, question: question_map[code] } }
  end
end
