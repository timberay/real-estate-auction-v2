module RightsAnalysis
  class DividendSimulator
    def self.call(rights:, tenants:, seizures:, expected_bid:, auction_cost: 3_000_000)
      new(rights:, tenants:, seizures:, expected_bid:, auction_cost:).call
    end

    def initialize(rights:, tenants:, seizures:, expected_bid:, auction_cost:)
      @rights = rights || []
      @tenants = tenants || []
      @seizures = seizures || []
      @expected_bid = expected_bid
      @auction_cost = auction_cost
    end

    def call
      if @expected_bid.nil?
        return {
          expected_bid: nil,
          distribution: [],
          bidder_burden: compute_bidder_burden([])
        }
      end

      remaining = @expected_bid
      distribution = []

      # Priority 0: Auction costs
      cost_dividend = [ @auction_cost, remaining ].min
      distribution << { priority: 0, holder: "경매 비용", type: "경매 비용",
                         claim: @auction_cost, dividend: cost_dividend, shortfall: @auction_cost - cost_dividend }
      remaining -= cost_dividend

      # Priority 1: Small-sum tenant priority repayment
      small_sum = @tenants.select { |t| t[:is_small_sum_tenant] && t[:has_opposing_power] }
      small_sum.each do |tenant|
        claim = tenant[:deposit]
        dividend = [ claim, remaining ].min
        distribution << { priority: 1, holder: tenant[:name], type: "소액임차인",
                           claim: claim, dividend: dividend, shortfall: claim - dividend }
        remaining -= dividend
      end

      # Priority 2: Current-year tax
      @seizures.each do |seizure|
        claim = seizure["amount"] || seizure[:amount]
        dividend = [ claim, remaining ].min
        holder = seizure["holder"] || seizure[:holder]
        distribution << { priority: 2, holder: holder, type: "당해세",
                           claim: claim, dividend: dividend, shortfall: claim - dividend }
        remaining -= dividend
      end

      # Priority 3: Mortgages/lease rights by establishment date
      mortgages = @rights
        .select { |r| %w[근저당 전세권].include?(r["type"] || r[:type]) }
        .sort_by { |r| Date.parse(r["date"] || r[:date].to_s) }
      mortgages.each do |right|
        claim = right["amount"] || right[:amount]
        holder = right["holder"] || right[:holder]
        type = right["type"] || right[:type]
        dividend = [ claim, remaining ].min
        distribution << { priority: 3, holder: holder, type: type,
                           claim: claim, dividend: dividend, shortfall: claim - dividend }
        remaining -= dividend
      end

      # Priority 4: Tenants with confirmed date (non-small-sum, with opposing power and dividend request)
      confirmed_tenants = @tenants
        .reject { |t| t[:is_small_sum_tenant] }
        .select { |t| t[:has_opposing_power] && t[:dividend_requested] && t[:confirmed_date] }
        .sort_by { |t| Date.parse(t[:confirmed_date]) }
      confirmed_tenants.each do |tenant|
        claim = tenant[:deposit]
        dividend = [ claim, remaining ].min
        distribution << { priority: 4, holder: tenant[:name], type: "확정일자 임차인",
                           claim: claim, dividend: dividend, shortfall: claim - dividend }
        remaining -= dividend
      end

      # Priority 5: General creditors
      general = @rights.select { |r| %w[가압류 압류 강제경매개시결정].include?(r["type"] || r[:type]) }
      general.each do |right|
        claim = right["amount"] || right[:amount]
        holder = right["holder"] || right[:holder]
        type = right["type"] || right[:type]
        dividend = [ claim, remaining ].min
        distribution << { priority: 5, holder: holder, type: type,
                           claim: claim, dividend: dividend, shortfall: claim - dividend }
        remaining -= dividend
      end

      {
        expected_bid: @expected_bid,
        distribution: distribution,
        bidder_burden: compute_bidder_burden(distribution)
      }
    end

    private

    def compute_bidder_burden(distribution)
      assumed = @tenants
        .select { |t| t[:has_opposing_power] && !t[:dividend_requested] }
        .sum { |t| t[:deposit] || 0 }

      unconfirmed = @tenants
        .select { |t| t[:has_opposing_power] && t[:dividend_requested] && t[:confirmed_date].nil? }
        .sum { |t| t[:deposit] || 0 }

      total = assumed + unconfirmed
      verdict = if total == 0
        "safe"
      elsif assumed == 0 && unconfirmed > 0
        "caution"
      else
        "danger"
      end

      { assumed_amount: assumed, unconfirmed_risk: unconfirmed, total_burden: total, verdict: verdict }
    end
  end
end
