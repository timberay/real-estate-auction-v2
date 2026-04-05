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

puts "Seed complete!"
