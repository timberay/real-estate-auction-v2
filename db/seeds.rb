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
  next unless group["property_type_code"]
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
  "권리분석" => "rights_analysis",
  "물건분석" => "property_analysis",
  "수익분석" => "profit_analysis",
  "현장확인" => "field_check",
  "입찰&낙찰" => "bidding"
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

puts "Seeding properties from live court auction data..."
guest = User.find_by!(email: "guest@auction.local")
Property.destroy_all
real_properties = JSON.parse(File.read(Rails.root.join("db/seeds/real_properties.json")))
real_properties.each do |attrs|
  property = Property.find_or_initialize_by(case_number: attrs["case_number"])
  property.assign_attributes(
    case_type: attrs["case_type"],
    claim_amount: attrs["claim_amount"],
    property_type: attrs["property_type"],
    property_usage_code: attrs["property_usage_code"],
    status: attrs.fetch("status", "진행중"),
    address: attrs["address"],
    sido: attrs["sido"],
    sigungu: attrs["sigungu"],
    dong: attrs["dong"],
    building_name: attrs["building_name"],
    building_detail: attrs["building_detail"],
    building_structure: attrs["building_structure"],
    exclusive_area: attrs["exclusive_area"],
    land_category: attrs["land_category"],
    appraisal_price: attrs["appraisal_price"],
    min_bid_price: attrs["min_bid_price"],
    failed_bid_count: attrs["failed_bid_count"],
    view_count: attrs.fetch("view_count", 0),
    interest_count: attrs.fetch("interest_count", 0),
    latitude: attrs["latitude"],
    longitude: attrs["longitude"],
    special_conditions_code: attrs["special_conditions_code"],
    remarks: attrs["remarks"]
  )
  property.save!

  if attrs["sale_detail"]
    sd = attrs["sale_detail"]
    detail = property.sale_detail || property.build_sale_detail
    detail.assign_attributes(
      non_extinguished_rights: sd["non_extinguished_rights"],
      superficies_details: sd["superficies_details"],
      specification_remarks: sd["specification_remarks"],
      senior_mortgage_basis: sd["senior_mortgage_basis"],
      goods_remarks: sd["goods_remarks"],
      dividend_demand_deadline: sd["dividend_demand_deadline"],
      share_description: sd["share_description"],
      price_round_1: sd["price_round_1"],
      price_round_2: sd["price_round_2"],
      price_round_3: sd["price_round_3"],
      price_round_4: sd["price_round_4"]
    )
    detail.save!
  end

  (attrs["auction_schedules"] || []).each do |s|
    property.auction_schedules.create!(s.symbolize_keys.slice(
      :schedule_date, :schedule_time, :bid_start_date, :bid_end_date,
      :place, :schedule_type, :result_code, :min_price, :sale_amount
    ))
  end

  (attrs["land_details"] || []).each do |l|
    property.land_details.create!(l.symbolize_keys.slice(
      :land_type, :land_area, :land_category, :share_ratio, :address, :lot_number
    ))
  end

  (attrs["appraisal_points"] || []).each do |p|
    property.appraisal_points.create!(p.symbolize_keys.slice(:item_code, :content))
  end

  guest.user_properties.find_or_create_by!(property: property)
end
puts "  -> #{Property.count} properties (#{guest.user_properties.count} linked to guest)"

puts "Seed complete!"
