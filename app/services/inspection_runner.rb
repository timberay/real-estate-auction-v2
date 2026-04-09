class InspectionRunner
  DETECTION_RULES = {
    # 매각물건명세서 tab
    "rights-002" => ->(p) {
      text = p.sale_detail&.non_extinguished_rights
      return nil if text.nil? && p.sale_detail.nil?
      text.present?
    },
    "rights-011" => ->(p) {
      combined = [p.remarks, p.sale_detail&.specification_remarks, p.sale_detail&.goods_remarks].compact.join("\n")
      combined.match?(/유치권|법정지상권/)
    },
    "rights-005" => ->(p) { nil }, # use_approval not available
    "rights-003" => ->(p) { nil }, # tenants not available
    "rights-006" => ->(p) { nil }, # tenants not available
    "rights-014" => ->(p) { nil }, # tenants not available
    "property-002" => ->(p) {
      combined = [p.remarks, p.sale_detail&.specification_remarks, p.sale_detail&.goods_remarks].compact.join("\n")
      return nil if combined.blank? && p.sale_detail.nil?
      combined.match?(/벽체|구조변경|불법.*증축|불법.*개축/) ? true : false
    },
    "rights-019" => ->(p) {
      cat = p.land_category
      return nil if cat.nil?
      cat != "전유"
    },
    "rights-020" => ->(p) {
      combined = [p.remarks, p.sale_detail&.specification_remarks, p.sale_detail&.goods_remarks].compact.join("\n")
      return nil if combined.blank? && p.sale_detail.nil?
      combined.match?(/유치권/) ? true : false
    },
    "resale-003" => ->(p) {
      floor = p.building_detail
      return nil if floor.blank?
      floor.match?(/지하|반지하/) && !floor.match?(/지상/)
    },
    # 등기부등본 tab — still reads raw_data
    "rights-001" => ->(p) { p.raw_data&.dig("registry_transcript", "provisional_disposition_senior") == true },
    "rights-007" => ->(p) { p.raw_data&.dig("registry_transcript", "notice_registration") == true },
    "rights-008" => ->(p) { p.raw_data&.dig("registry_transcript", "senior_tax_seizure") == true },
    # 건축물대장 tab — still reads raw_data
    "property-004" => ->(p) { p.raw_data&.dig("building_ledger", "violation_flag") == true },
    "property-005" => ->(p) { p.raw_data&.dig("building_ledger", "usage_type") == "사무소" },
    "resale-002" => ->(p) { (p.raw_data&.dig("building_ledger", "parking_per_unit") || 99) < 0.5 },
    # 온라인조회 tab
    "property-001" => ->(p) { p.sale_detail&.share_description.present? }
  }.freeze

  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    # Eager load sale_detail to avoid N+1
    @property.sale_detail

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
          rule.call(@property)
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
