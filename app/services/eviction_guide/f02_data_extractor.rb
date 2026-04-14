module EvictionGuide
  class F02DataExtractor
    MAPPINGS = %i[
      has_opposing_tenant is_dividend_requested has_lien
      has_gratuitous_residence_doc occupant_type has_small_sum_tenant
      has_rights_analysis
    ].freeze

    def self.call(property)
      new(property).call
    end

    def initialize(property)
      @property = property
      @report = property.rights_analysis_reports.last
      @user = property.user_properties.first&.user
    end

    def call
      return {} unless @report

      MAPPINGS.each_with_object({}) do |field, result|
        value = extract(field)
        result[field] = value unless value.nil?
      end
    end

    private

    def extract(field)
      case field
      when :has_rights_analysis
        @report.present?
      when :has_opposing_tenant
        tenants = @report&.effective_tenants
        return nil unless tenants.present?
        tenants.any? { |t| t["opposing_power"] }
      when :is_dividend_requested
        tenants = @report&.effective_tenants
        return nil unless tenants.present?
        tenants.any? { |t| t["dividend_requested"] }
      when :has_lien
        find_inspection_risk("rights-020")
      when :has_gratuitous_residence_doc
        find_inspection_risk("inspect-005")
      when :occupant_type
        @report&.parsed_data&.dig("occupant_type")
      when :has_small_sum_tenant
        tenants = @report&.effective_tenants
        return nil unless tenants.present?
        tenants.any? { |t| t["has_priority_repayment"] }
      end
    end

    def find_inspection_risk(item_code)
      return nil unless @user
      item = InspectionItem.find_by(code: item_code)
      return nil unless item
      result = InspectionResult.find_by(
        property: @property,
        inspection_item: item,
        user: @user
      )
      result&.has_risk
    end
  end
end
