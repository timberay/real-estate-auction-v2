module RightsAnalysis
  class OpposingPowerDeterminer
    def self.call(registry_data, base_right)
      return [] if registry_data.nil?

      tenants = registry_data["tenants"] || []
      return [] if tenants.empty?

      tenants.map do |tenant|
        has_power = if base_right.nil?
          false
        else
          move_in_date = Date.parse(tenant["move_in_date"])
          opposing_power_date = move_in_date + 1
          opposing_power_date <= base_right[:date]
        end

        {
          name: tenant["name"],
          deposit: tenant["deposit"],
          move_in_date: tenant["move_in_date"],
          confirmed_date: tenant["confirmed_date"],
          dividend_requested: tenant["dividend_requested"],
          is_small_sum_tenant: tenant["is_small_sum_tenant"],
          has_opposing_power: has_power
        }
      end
    end
  end
end
