class AutoCheckRunner
  DETECTION_RULES = {
    "rights-011" => ->(raw) { raw.dig("court_auction", "remarks")&.match?(/유치권|법정지상권/) },
    "rights-002" => ->(raw) { raw.dig("court_auction", "non_extinguished_rights")&.any? },
    "rights-019" => ->(raw) { raw.dig("court_auction", "separate_land_registry") == true },
    "rights-020" => ->(raw) { raw.dig("court_auction", "lien_reported") == true },
    "rights-003" => ->(raw) { raw.dig("court_auction", "tenants")&.any? },
    "rights-006" => ->(raw) {
      tenants = raw.dig("court_auction", "tenants") || []
      tenants.any? { |t| t["dividend_requested"] == false }
    },
    "rights-014" => ->(raw) {
      tenants = raw.dig("court_auction", "tenants") || []
      tenants.any? { |t| t["deposit"].nil? || t["dividend_requested"] == false }
    },
    "manual-001" => nil,
    "property-001" => ->(raw) { raw.dig("court_auction", "is_partial_share") == true },
    "property-005" => ->(raw) { raw.dig("building_ledger", "usage_type") == "사무소" },
    "resale-001" => ->(raw) { (raw.dig("building_ledger", "room_count") || 99) <= 1 },
    "resale-002" => ->(raw) { (raw.dig("building_ledger", "parking_per_unit") || 99) < 0.5 },
    "resale-003" => ->(raw) { raw.dig("building_ledger", "floor_info")&.include?("반지하") },
    "resale-004" => nil,
    "property-004" => ->(raw) { raw.dig("building_ledger", "violation_flag") == true },
    "rights-005" => ->(raw) { raw.dig("court_auction", "use_approval") == false },
    "property-002" => ->(raw) { raw.dig("court_auction", "wall_partition_issue") == true }
  }.freeze

  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    raw = @property.raw_data || {}

    ChecklistItem.ordered.map do |item|
      rule = DETECTION_RULES[item.code]
      result = @property.property_check_results.find_or_initialize_by(checklist_item: item, user: @user)

      if rule.nil?
        result.assign_attributes(source_type: nil, has_risk: nil)
      else
        detected = rule.call(raw)
        if detected.nil?
          result.assign_attributes(source_type: nil, has_risk: nil)
        else
          result.assign_attributes(source_type: "auto", has_risk: detected)
        end
      end

      result.save!
      result
    end
  end
end
