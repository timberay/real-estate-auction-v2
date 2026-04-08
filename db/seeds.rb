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
  ReserveFundDefault.where(property_type: pt).destroy_all
  group["defaults"].each do |attrs|
    ReserveFundDefault.create!(
      property_type: pt,
      area_range_min: attrs["area_range_min"],
      area_range_max: attrs["area_range_max"],
      average_price: attrs["average_price"],
      repair_cost: attrs["repair_cost"],
      acquisition_tax_rate: attrs["acquisition_tax_rate"],
      scrivener_fee: attrs["scrivener_fee"],
      moving_cost: attrs["moving_cost"],
      maintenance_fee: attrs["maintenance_fee"]
    )
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

puts "Seeding inspection items..."

TAB_MAP = {
  "매각물건명세서" => "sale_document",
  "등기부등본" => "registry",
  "건축물대장" => "building_ledger",
  "온라인조회" => "online",
  "현장임장" => "field_visit",
  "기타" => "etc"
}.freeze

inspection_data = JSON.parse(File.read(Rails.root.join("db/seeds/checklist_items_summary.json")))
seeded_codes = []

inspection_data.each do |attrs|
  code = attrs["id"]
  next unless code

  tab_key = TAB_MAP[attrs["tab"]]
  next unless tab_key

  item = InspectionItem.find_or_initialize_by(code: code)
  item.assign_attributes(
    tab: tab_key,
    tab_position: attrs["tab_position"],
    category: attrs["category"],
    question: attrs["question"],
    description: attrs["description"],
    logic: attrs["logic"],
    data_source_name: attrs.dig("data_source", 0, "name") || "수동 입력",
    priority: attrs["priority"],
    merged_from: attrs["merged_from"],
    answer_type: attrs["answer_type"],
    yes_means_safe: attrs.fetch("yes_means_safe", true)
  )
  item.save!
  seeded_codes << code
end

removed = InspectionItem.where.not(code: seeded_codes).destroy_all
puts "  -> #{InspectionItem.count} inspection items (removed #{removed.size} stale)"

puts "Seeding mock properties..."
guest = User.find_by!(email: "guest@auction.local")
mock_properties = JSON.parse(File.read(Rails.root.join("db/seeds/mock_properties.json")))
mock_properties.each do |attrs|
  property = PropertyDataSyncService.call(case_number: attrs["case_number"])
  guest.user_properties.find_or_create_by!(property: property) if property
end
puts "  -> #{Property.count} properties (#{guest.user_properties.count} linked to guest)"

puts "Seed complete!"
