module RightsAnalysis
  class OpportunityDetector
    def self.call(registry_data:, tenants:, check_results:)
      new(registry_data:, tenants:, check_results:).call
    end

    def initialize(registry_data:, tenants:, check_results:)
      @registry_data = registry_data || {}
      @tenants = tenants || []
      @check_results = check_results || []
    end

    def call
      return hug_waiver_opportunity if hug_waiver?
      return full_dividend_opportunity if full_dividend?

      { opportunity_type: nil, opportunity_reason: nil }
    end

    private

    def hug_waiver?
      @registry_data["hug_waiver"] == true
    end

    def full_dividend?
      opposing_tenants = @tenants.select { |t| t[:has_opposing_power] }
      return false if opposing_tenants.empty?

      opposing_tenants.all? do |t|
        t[:dividend_requested] && t[:confirmed_date] && t[:estimated_dividend] && t[:estimated_dividend] >= (t[:deposit] || 0)
      end
    end

    def hug_waiver_opportunity
      {
        opportunity_type: "hug_waiver",
        opportunity_reason: "HUG(주택도시보증공사)가 대항력을 포기하여, 임차인 보증금 인수 부담이 없습니다."
      }
    end

    def full_dividend_opportunity
      {
        opportunity_type: "full_dividend",
        opportunity_reason: "대항력 있는 임차인이 배당을 통해 보증금 전액을 회수할 수 있어, 낙찰자의 실질 인수 부담이 없습니다."
      }
    end
  end
end
