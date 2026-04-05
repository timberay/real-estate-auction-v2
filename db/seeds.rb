require "json"

puts "Seeding property types..."
property_types_data = JSON.parse(File.read(Rails.root.join("db/seeds/property_types.json")))
property_types_data.each do |attrs|
  PropertyType.find_or_create_by!(code: attrs["code"]) do |pt|
    pt.name = attrs["name"]
    pt.enabled = attrs["enabled"]
    pt.sort_order = attrs["sort_order"]
  end
end
puts "  -> #{PropertyType.count} property types"

puts "Seeding reserve fund defaults..."
reserve_data = JSON.parse(File.read(Rails.root.join("db/seeds/reserve_fund_defaults.json")))
reserve_data.each do |group|
  pt = PropertyType.find_by!(code: group["property_type_code"])
  group["defaults"].each do |attrs|
    ReserveFundDefault.find_or_create_by!(
      property_type: pt,
      area_range_min: attrs["area_range_min"],
      area_range_max: attrs["area_range_max"]
    ) do |rfd|
      rfd.repair_cost = attrs["repair_cost"]
      rfd.acquisition_tax_rate = attrs["acquisition_tax_rate"]
      rfd.scrivener_fee = attrs["scrivener_fee"]
      rfd.moving_cost = attrs["moving_cost"]
      rfd.maintenance_fee = attrs["maintenance_fee"]
    end
  end
end
puts "  -> #{ReserveFundDefault.count} reserve fund defaults"

puts "Seeding loan policies..."
loan_data = JSON.parse(File.read(Rails.root.join("db/seeds/loan_policies.json")))
loan_data.each do |group|
  pt = PropertyType.find_by!(code: group["property_type_code"])
  group["policies"].each do |attrs|
    LoanPolicy.find_or_create_by!(
      property_type: pt,
      policy_name: attrs["policy_name"]
    ) do |lp|
      lp.loan_ratio = attrs["loan_ratio"]
      lp.description = attrs["description"]
      lp.source_url = attrs["source_url"]
      lp.effective_date = Date.parse(attrs["effective_date"])
      lp.enabled = true
    end
  end
end
puts "  -> #{LoanPolicy.count} loan policies"

puts "Seeding guest user..."
User.find_or_create_by!(email: "guest@auction.local") do |u|
  u.password = "123456"
end
puts "  -> Guest user ready"

puts "Seeding checklist items..."

# Position defines display order within F02 analysis flow
F02_POSITIONS = {
  "rights-011" => 1, "rights-002" => 2, "rights-019" => 3, "rights-020" => 4,
  "rights-003" => 5, "rights-006" => 6, "rights-014" => 7, "manual-001" => 8,
  "property-001" => 9, "property-005" => 10, "resale-001" => 11, "resale-002" => 12,
  "resale-003" => 13, "resale-004" => 14, "property-004" => 15, "rights-005" => 16,
  "property-002" => 17
}.freeze

checklist_data = JSON.parse(File.read(Rails.root.join("db/seeds/checklist_items_summary.json")))
checklist_data.each do |attrs|
  code = attrs["id"]
  next unless code
  next unless attrs["f02_risk_axis"]

  position = F02_POSITIONS[code]
  next unless position

  ChecklistItem.find_or_create_by!(code: code) do |item|
    item.category = attrs["category"]
    item.risk_axis = attrs["f02_risk_axis"]
    item.question = attrs["question"]
    item.description = attrs["description"]
    item.logic = attrs["logic"]
    item.data_source_name = attrs.dig("data_source", 0, "name") || "수동 입력"
    item.priority = attrs["priority"]
    item.position = position
  end
end
puts "  -> #{ChecklistItem.count} checklist items (expected: 17)"

puts "Seed complete!"
