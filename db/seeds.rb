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
      repair_cost: attrs["repair_cost"],
      scrivener_fee: attrs["scrivener_fee"],
      moving_cost: attrs["moving_cost"],
      maintenance_fee: attrs["maintenance_fee"]
    )
  end
end
puts "  -> #{ReserveFundDefault.count} reserve fund defaults"

puts "Seeding acquisition tax rates..."
tax_data = JSON.parse(File.read(Rails.root.join("db/seeds/acquisition_tax_rates.json")))
tax_data.each do |group|
  next unless group["property_type_code"]
  pt = PropertyType.find_by!(code: group["property_type_code"])
  AcquisitionTaxRate.where(property_type: pt).destroy_all
  group["rates"].each do |attrs|
    AcquisitionTaxRate.create!(
      property_type: pt,
      household_tier: attrs["household_tier"],
      regulated_region: attrs["regulated_region"],
      price_bucket_min_manwon: attrs["price_bucket_min_manwon"],
      price_bucket_max_manwon: attrs["price_bucket_max_manwon"],
      area_over_85: attrs["area_over_85"],
      total_rate: attrs["total_rate"]
    )
  end
end
puts "  -> #{AcquisitionTaxRate.count} acquisition tax rates"

puts "Seeding transfer tax rates..."
transfer_data = JSON.parse(File.read(Rails.root.join("db/seeds/transfer_tax_matrix.json")))
transfer_data.each do |group|
  next unless group["property_type_code"]
  pt = PropertyType.find_by!(code: group["property_type_code"])
  TransferTaxRate.where(property_type: pt).destroy_all
  group["rates"].each do |attrs|
    TransferTaxRate.create!(
      property_type: pt,
      household_tier: attrs["household_tier"],
      holding_period: attrs["holding_period"],
      regulated_region: attrs["regulated_region"],
      total_rate: attrs["total_rate"]
    )
  end
end
puts "  -> #{TransferTaxRate.count} transfer tax rates"

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
      lp.regulated_loan_ratio = attrs["regulated_loan_ratio"]
      lp.description = attrs["description"]
      lp.source_url = attrs["source_url"]
      lp.effective_date = Date.parse(attrs["effective_date"])
      lp.enabled = true
    end
  end
end
puts "  -> #{LoanPolicy.count} loan policies"

puts "Seeding guest user..."
User.find_or_create_by!(email: "guest@auction.local")
puts "  -> Guest user ready"

puts "Seeding inspection items..."

TAB_MAP = {
  "권리분석" => "rights_analysis",
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
    yes_means_safe: attrs.fetch("yes_means_safe", true),
    applicable_types: attrs["applicable_types"],
    depends_on: attrs["depends_on"]
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

  (attrs["auction_schedules"] || []).each do |s|
    property.auction_schedules.create!(s.symbolize_keys.slice(
      :schedule_date, :schedule_time, :bid_start_date, :bid_end_date,
      :place, :schedule_type, :result_code, :min_price, :sale_amount
    ))
  end

  guest.user_properties.find_or_create_by!(property: property)
end
puts "  -> #{Property.count} properties (#{guest.user_properties.count} linked to guest)"

puts "Seeding eviction steps..."
eviction_data = JSON.parse(File.read(Rails.root.join("db/seeds/eviction_steps.json")))

(eviction_data["steps"] + eviction_data["branches"]).each do |attrs|
  EvictionStep.find_or_create_by!(code: attrs["code"]) do |step|
    step.step_type = attrs["step_type"]
    step.name = attrs["name"]
    step.description = attrs["description"]
    step.completion_condition = attrs["completion_condition"]
    step.failure_condition = attrs["failure_condition"]
    step.required_documents = attrs["required_documents"]
    step.estimated_duration = attrs["estimated_duration"]
    step.estimated_cost = attrs["estimated_cost"]
    step.legal_basis = attrs["legal_basis"]
    step.position = attrs["position"]
    step.next_step_code = attrs["next_step_code"]
    step.branch_codes = attrs["branch_codes"]
    step.trigger_step_code = attrs["trigger_step_code"]
    step.problem_summary = attrs["problem_summary"]
    step.root_cause = attrs["root_cause"]
    step.action_steps = attrs["action_steps"]
    step.return_step_code = attrs["return_step_code"]
    step.occupant_type = attrs["occupant_type"]
  end
end
puts "  -> #{EvictionStep.count} eviction steps"

puts "Seeding eviction simulator questions..."
questions_data = JSON.parse(File.read(Rails.root.join("db/seeds/eviction_simulator_questions.json")))
questions_data.each do |attrs|
  EvictionSimulatorQuestion.find_or_create_by!(code: attrs["code"]) do |q|
    q.phase = attrs["phase"]
    q.step_code = attrs["step_code"]
    q.question = attrs["question"]
    q.help_text = attrs["help_text"]
    q.yes_next_code = attrs["yes_next_code"]
    q.no_next_code = attrs["no_next_code"]
    q.f02_field_mapping = attrs["f02_field_mapping"]
    q.difficulty_impact = attrs["difficulty_impact"]
    q.occupant_type = attrs["occupant_type"]
  end
end
puts "  -> #{EvictionSimulatorQuestion.count} simulator questions"

puts "Seed complete!"
