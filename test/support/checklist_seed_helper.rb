module ChecklistSeedHelper
  TAB_MAP = {
    "권리분석" => "rights_analysis",
    "수익분석" => "profit_analysis",
    "현장확인" => "field_check",
    "입찰&낙찰" => "bidding"
  }.freeze

  def load_checklist_seed!
    InspectionResult.delete_all
    InspectionItem.delete_all

    json_path = Rails.root.join("db/seeds/checklist_items_summary.json")
    JSON.parse(File.read(json_path)).each do |attrs|
      tab_key = TAB_MAP[attrs["tab"]]
      next unless tab_key
      InspectionItem.create!(
        code: attrs["id"],
        tab: tab_key,
        tab_position: attrs["tab_position"],
        category: attrs["category"],
        question: attrs["question"],
        description: attrs["description"],
        logic: attrs["logic"],
        priority: attrs["priority"],
        merged_from: attrs["merged_from"],
        answer_type: attrs["answer_type"],
        yes_means_safe: attrs.fetch("yes_means_safe", true),
        applicable_types: attrs["applicable_types"],
        depends_on: attrs["depends_on"]
      )
    end
  end
end
