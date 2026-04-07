class InspectionRunner
  DETECTION_RULES = {
    # 매각물건명세서 tab
    "rights-002" => ->(raw) { raw.dig("court_auction", "non_extinguished_rights")&.any? },
    "rights-011" => ->(raw) { raw.dig("court_auction", "remarks")&.match?(/유치권|법정지상권/) },
    "rights-005" => ->(raw) { raw.dig("court_auction", "use_approval") == false },
    "rights-003" => ->(raw) { raw.dig("court_auction", "tenants")&.any? },
    "rights-006" => ->(raw) {
      tenants = raw.dig("court_auction", "tenants") || []
      tenants.any? { |t| t["dividend_requested"] == false }
    },
    "rights-014" => ->(raw) {
      tenants = raw.dig("court_auction", "tenants") || []
      tenants.any? { |t| t["deposit"].nil? || t["dividend_requested"] == false }
    },
    "property-002" => ->(raw) { raw.dig("court_auction", "wall_partition_issue") == true },
    "rights-019" => ->(raw) { raw.dig("court_auction", "separate_land_registry") == true },
    "rights-020" => ->(raw) { raw.dig("court_auction", "lien_reported") == true },
    "resale-003" => ->(raw) { raw.dig("building_ledger", "floor_info")&.include?("반지하") },

    # 등기부등본 tab
    "rights-001" => ->(raw) { raw.dig("registry_transcript", "provisional_disposition_senior") == true },
    "rights-007" => ->(raw) { raw.dig("registry_transcript", "notice_registration") == true },
    "rights-008" => ->(raw) { raw.dig("registry_transcript", "senior_tax_seizure") == true },

    # 건축물대장 tab
    "property-004" => ->(raw) { raw.dig("building_ledger", "violation_flag") == true },
    "property-005" => ->(raw) { raw.dig("building_ledger", "usage_type") == "사무소" },
    "resale-002" => ->(raw) { (raw.dig("building_ledger", "parking_per_unit") || 99) < 0.5 },

    # 온라인조회 tab
    "property-001" => ->(raw) { raw.dig("court_auction", "is_partial_share") == true }
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

    InspectionItem.ordered.map do |item|
      result = @property.inspection_results.find_or_initialize_by(inspection_item: item, user: @user)

      rule = DETECTION_RULES[item.code]
      if rule.nil?
        # No detection rule — leave as unanswered unless user already manually answered
        unless result.persisted? && result.source_type.present?
          result.assign_attributes(source_type: nil, has_risk: nil)
        end
      else
        detected = begin
          rule.call(raw)
        rescue
          nil
        end
        if detected.nil?
          unless result.persisted? && result.source_type.present?
            result.assign_attributes(source_type: nil, has_risk: nil)
          end
        else
          result.assign_attributes(source_type: "auto", has_risk: detected)
        end
      end

      result.save!
      result
    end
  end
end
