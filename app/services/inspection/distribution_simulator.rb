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
  #   - 당해세 (property-specific tax) — needs typed tax rights from rights_timeline
  #   - Exact 집행비용 — defaulted to a flat 3% estimate
  #
  # Waterfall order:
  #   1. 집행비용 (EXECUTION_COST_RATE of sale price)
  #   2. 최우선변제 (small-tenant first-priority, if `property` is supplied) — aggregate capped at sale/2
  #   3. Priority claims (extinguishing 근저당 + tenants w/ 확정일자) sorted by date asc
  #   4. Remaining for general creditors
  class DistributionSimulator
    EXECUTION_COST_RATE = 0.03

    # Tenants paid before liens when dates tie (tenant 우선변제 takes the same date slot first).
    KIND_TIEBREAK = { "tenant" => 0, "lien" => 1 }.freeze

    DISCLAIMER = "본 시뮬레이션은 추정치입니다. 집행비용은 매각가의 3%로 단순 가정했고, " \
                 "최우선변제(소액임차인)는 시행령 별표(시기·지역) 기준으로 추정했습니다. " \
                 "당해세는 계산에서 제외했습니다. 실제 배당과 차이가 있을 수 있으니 참고용으로만 사용하세요.".freeze

    Result = Struct.new(
      :sale_price,
      :execution_costs,
      :distributions,
      :tenant_outcomes,
      :buyer_assumed_amount,
      :remaining_for_general,
      :small_tenant_period,
      :disclaimer,
      keyword_init: true
    )

    def self.call(sale_price:, validated_tenants:, rights_timeline:, property: nil)
      new(sale_price:, validated_tenants:, rights_timeline:, property:).call
    end

    def initialize(sale_price:, validated_tenants:, rights_timeline:, property: nil)
      @sale_price = sale_price.to_i
      @validated_tenants = validated_tenants || []
      @rights_timeline = rights_timeline || []
      @property = property
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
          small_tenant_period: small_tenant_period_info,
          disclaimer: DISCLAIMER
        )
      end

      execution_costs = (@sale_price * EXECUTION_COST_RATE).round
      remaining = @sale_price - execution_costs

      distributions = [ { "kind" => "execution_cost", "label" => "집행비용 (추정 3%)", "amount" => execution_costs } ]

      first_priority_dividends = compute_first_priority_dividends
      first_priority_total = first_priority_dividends.values.sum
      first_priority_total = [ first_priority_total, remaining ].min  # never exceed remaining
      remaining -= first_priority_total

      first_priority_dividends.each do |tenant_key, amount|
        next unless amount.positive?
        name = first_priority_tenant_names[tenant_key]
        distributions << {
          "kind" => "first_priority",
          "label" => "최우선변제 #{name} (소액임차인)",
          "amount" => amount
        }
      end

      claimants = build_claimants(first_priority_dividends)
      tenant_dividends = Hash.new(0).merge(first_priority_dividends)

      claimants.each do |claimant|
        break if remaining <= 0
        payout = [ remaining, claimant[:amount] ].min
        remaining -= payout

        distributions << { "kind" => claimant[:kind], "label" => claimant[:label], "amount" => payout }
        tenant_dividends[claimant[:tenant_key]] += payout if claimant[:kind] == "tenant"
      end

      tenant_outcomes = build_tenant_outcomes(tenant_dividends)

      Result.new(
        sale_price: @sale_price,
        execution_costs: execution_costs,
        distributions: distributions,
        tenant_outcomes: tenant_outcomes,
        buyer_assumed_amount: opposing_unrecovered(tenant_outcomes),
        remaining_for_general: remaining,
        small_tenant_period: small_tenant_period_info,
        disclaimer: DISCLAIMER
      )
    end

    private

    def small_tenant_protection
      return @small_tenant_protection if defined?(@small_tenant_protection)
      @small_tenant_protection =
        if @property
          SmallTenantProtection.lookup(
            sido: @property.try(:sido),
            sigungu: @property.try(:sigungu),
            period_date: earliest_extinguishing_lien_date
          )
        end
    end

    def small_tenant_period_info
      protection = small_tenant_protection
      return nil unless protection
      {
        tier: protection[:tier],
        deposit_cap: protection[:deposit_cap],
        protection_amount: protection[:protection_amount],
        period_label: protection[:period_label]
      }
    end

    def earliest_extinguishing_lien_date
      dates = @rights_timeline
        .select { |r| r["extinguished_on_sale"] && lien_type?(r["type"]) }
        .map { |r| r["registered_date"] || r["date"] }
        .compact
        .reject(&:blank?)
      dates.min
    end

    def compute_first_priority_dividends
      protection = small_tenant_protection
      return {} unless protection

      requested = eligible_first_priority_tenants(protection).each_with_object({}) do |tenant, acc|
        deposit = tenant["deposit"].to_i
        amount = [ deposit, protection[:protection_amount] ].min
        next unless amount.positive?
        acc[tenant_key(tenant)] = amount
      end

      return {} if requested.empty?

      aggregate_cap = (@sale_price / 2.0).floor
      total_requested = requested.values.sum

      if total_requested <= aggregate_cap
        requested
      else
        # Pro-rate proportionally when aggregate exceeds 1/2 sale price (시행령 §10③).
        prorated = requested.transform_values do |amount|
          (amount.to_f * aggregate_cap / total_requested).floor
        end
        # Rounding shave-off — distribute the remainder to keep sum == cap.
        deficit = aggregate_cap - prorated.values.sum
        if deficit.positive?
          prorated.each_key do |k|
            break if deficit <= 0
            prorated[k] += 1
            deficit -= 1
          end
        end
        prorated
      end
    end

    def eligible_first_priority_tenants(protection)
      @validated_tenants.select do |tenant|
        tenant["move_in_date"].present? &&
          tenant["dividend_requested"] &&
          tenant["deposit"].to_i.positive? &&
          tenant["deposit"].to_i <= protection[:deposit_cap]
      end
    end

    def first_priority_tenant_names
      @first_priority_tenant_names ||= @validated_tenants.each_with_object({}) do |t, acc|
        acc[tenant_key(t)] = t["name"]
      end
    end

    # Build claimants competing for sale proceeds.
    # Only includes 근저당 with extinguished_on_sale=true (surviving liens stick to the property
    # and don't compete in distribution) and tenants with 확정일자 (has_priority_repayment).
    # Tenant amount is reduced by any first-priority dividend already paid.
    def build_claimants(first_priority_dividends)
      tenant_claimants = @validated_tenants
        .select { |t| t["has_priority_repayment"] && t["effective_date"].present? }
        .filter_map do |t|
          remaining_deposit = t["deposit"].to_i - first_priority_dividends.fetch(tenant_key(t), 0)
          next if remaining_deposit <= 0

          {
            kind: "tenant",
            label: "임차인 #{t['name']} 우선변제",
            amount: remaining_deposit,
            sort_date: t["effective_date"].to_s,
            tenant_key: tenant_key(t)
          }
        end

      lien_claimants = @rights_timeline
        .select { |r| r["extinguished_on_sale"] && lien_type?(r["type"]) && (r["registered_date"] || r["date"]).present? }
        .map do |r|
          {
            kind: "lien",
            label: "#{r['type']} #{r['holder']}".strip,
            amount: r["amount"].to_i,
            sort_date: (r["registered_date"] || r["date"]).to_s,
            tenant_key: nil
          }
        end

      (tenant_claimants + lien_claimants)
        .sort_by.with_index { |c, i| [ c[:sort_date], KIND_TIEBREAK[c[:kind]] || 99, i ] }
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

    # Only 근저당 competes via priority repayment with tenants. Other rights
    # (가압류, 전세권, etc.) are intentionally excluded from this simplified waterfall —
    # they're flagged elsewhere by RightsValidator.
    def lien_type?(type)
      type.to_s.gsub(/\s+/, "").include?("근저당")
    end
  end
end
