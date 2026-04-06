module RightsAnalysis
  class AssumedAmountCalculator
    def self.call(tenants)
      assumed_amount = 0
      total_risk_amount = 0

      tenants.each do |tenant|
        next unless tenant[:has_opposing_power]

        deposit = tenant[:deposit] || 0

        if !tenant[:dividend_requested]
          assumed_amount += deposit
          total_risk_amount += deposit
        elsif tenant[:confirmed_date].nil?
          total_risk_amount += deposit
        end
      end

      { assumed_amount: assumed_amount, total_risk_amount: total_risk_amount }
    end
  end
end
