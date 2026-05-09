module Inspection
  # Simplified Korean-auction distribution waterfall simulator.
  #
  # Computes per-tenant uncovered remainder given a hypothetical sale price.
  # The buyer's true assumed burden = sum of uncovered remainders for tenants
  # that retain opposing power (대항력). This is meaningfully smaller than
  # `RightsValidator#total_risk_amount`, which counts the full deposit as risk
  # without accounting for dividends.
  #
  # Out of scope (future tasks / acknowledged in disclaimer):
  #   - 최우선변제 (small-tenant minimum protection) — needs a regional/period matrix
  #   - 당해세 (property-specific tax) — needs typed tax rights from rights_timeline
  #   - Exact 집행비용 — defaulted to a flat 3% estimate
  #
  # Waterfall order implemented for B1:
  #   1. 집행비용 (EXECUTION_COST_RATE of sale price)
  #   2. Priority claims (extinguishing 근저당 + tenants w/ 확정일자) sorted by date asc
  #   3. Remaining for general creditors
  class DistributionSimulator
    EXECUTION_COST_RATE = 0.03

    DISCLAIMER = "본 시뮬레이션은 추정치입니다. 집행비용은 매각가의 3%로 단순 가정했고, " \
                 "최우선변제(소액임차인)와 당해세는 계산에서 제외했습니다. 실제 배당과 차이가 있을 수 있으니 참고용으로만 사용하세요.".freeze

    Result = Struct.new(
      :sale_price,
      :execution_costs,
      :distributions,
      :tenant_outcomes,
      :buyer_assumed_amount,
      :remaining_for_general,
      :disclaimer,
      keyword_init: true
    )

    def self.call(sale_price:, validated_tenants:, rights_timeline:)
      new(sale_price:, validated_tenants:, rights_timeline:).call
    end

    def initialize(sale_price:, validated_tenants:, rights_timeline:)
      @sale_price = sale_price.to_i
      @validated_tenants = validated_tenants || []
      @rights_timeline = rights_timeline || []
    end

    def call
      if @sale_price <= 0
        return Result.new(
          sale_price: 0,
          execution_costs: 0,
          distributions: [],
          tenant_outcomes: build_zero_tenant_outcomes,
          buyer_assumed_amount: opposing_unrecovered(build_zero_tenant_outcomes),
          remaining_for_general: 0,
          disclaimer: DISCLAIMER
        )
      end

      execution_costs = (@sale_price * EXECUTION_COST_RATE).round
      remaining = @sale_price - execution_costs

      distributions = [ { "kind" => "execution_cost", "label" => "집행비용 (추정 3%)", "amount" => execution_costs } ]

      claimants = build_claimants
      tenant_dividends = Hash.new(0)

      claimants.each do |claimant|
        break if remaining <= 0
        payout = [ remaining, claimant[:amount] ].min
        remaining -= payout

        distributions << { "kind" => claimant[:kind], "label" => claimant[:label], "amount" => payout }
        tenant_dividends[claimant[:tenant_key]] = payout if claimant[:kind] == "tenant"
      end

      tenant_outcomes = build_tenant_outcomes(tenant_dividends)

      Result.new(
        sale_price: @sale_price,
        execution_costs: execution_costs,
        distributions: distributions,
        tenant_outcomes: tenant_outcomes,
        buyer_assumed_amount: opposing_unrecovered(tenant_outcomes),
        remaining_for_general: remaining,
        disclaimer: DISCLAIMER
      )
    end

    private

    # Build claimants competing for sale proceeds.
    # Only includes 근저당 with extinguished_on_sale=true (surviving liens stick to the property
    # and don't compete in distribution) and tenants with 확정일자 (has_priority_repayment).
    def build_claimants
      tenant_claimants = @validated_tenants
        .select { |t| t["has_priority_repayment"] && t["effective_date"].present? }
        .map do |t|
          {
            kind: "tenant",
            label: "임차인 #{t['name']} 우선변제",
            amount: t["deposit"].to_i,
            sort_date: t["effective_date"].to_s,
            tenant_key: tenant_key(t)
          }
        end

      lien_claimants = @rights_timeline
        .select { |r| r["extinguished_on_sale"] && lien_type?(r["type"]) }
        .map do |r|
          {
            kind: "lien",
            label: "#{r['type']} #{r['holder']}".strip,
            amount: r["amount"].to_i,
            sort_date: (r["registered_date"] || r["date"]).to_s,
            tenant_key: nil
          }
        end

      (tenant_claimants + lien_claimants).sort_by { |c| c[:sort_date] }
    end

    def build_tenant_outcomes(tenant_dividends)
      @validated_tenants.map do |t|
        deposit = t["deposit"].to_i
        dividend = tenant_dividends[tenant_key(t)] || 0
        uncovered = [ deposit - dividend, 0 ].max
        {
          "name" => t["name"],
          "deposit" => deposit,
          "opposing_power" => t["opposing_power"] ? true : false,
          "dividend" => dividend,
          "uncovered_remainder" => uncovered
        }
      end
    end

    def build_zero_tenant_outcomes
      @validated_tenants.map do |t|
        deposit = t["deposit"].to_i
        {
          "name" => t["name"],
          "deposit" => deposit,
          "opposing_power" => t["opposing_power"] ? true : false,
          "dividend" => 0,
          "uncovered_remainder" => deposit
        }
      end
    end

    def opposing_unrecovered(tenant_outcomes)
      tenant_outcomes
        .select { |t| t["opposing_power"] }
        .sum { |t| t["uncovered_remainder"].to_i }
    end

    def tenant_key(tenant)
      [ tenant["name"], tenant["move_in_date"], tenant["confirmed_date"], tenant["deposit"] ]
    end

    # B1 scope: only 근저당 competes via priority repayment with tenants. Other rights
    # (가압류, 전세권, etc.) are intentionally excluded from this simplified waterfall —
    # they're flagged elsewhere by RightsValidator.
    def lien_type?(type)
      type.to_s.gsub(/\s+/, "").include?("근저당")
    end
  end
end
