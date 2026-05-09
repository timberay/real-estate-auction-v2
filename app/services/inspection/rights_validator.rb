module Inspection
  class RightsValidator
    Result = Struct.new(:validated_tenants, :validated_amounts, :discrepancies, keyword_init: true)

    UNEVALUATED_TYPES = %w[가등기 가처분 유치권 법정지상권 선순위세금압류].freeze

    def self.call(base_right_date:, tenants:, rights_timeline:)
      new(base_right_date:, tenants:, rights_timeline:).call
    end

    def initialize(base_right_date:, tenants:, rights_timeline:)
      @base_right_date = base_right_date.is_a?(String) ? Date.parse(base_right_date) : base_right_date
      @tenants = tenants || []
      @rights_timeline = rights_timeline || []
    end

    def call
      validated = @tenants.map { |t| validate_tenant(t) }
      discrepancies = detect_discrepancies(@tenants, validated)
      assign_priority_ranks!(validated)

      Result.new(
        validated_tenants: validated,
        validated_amounts: calculate_amounts(validated),
        discrepancies: discrepancies
      )
    end

    private

    def validate_tenant(tenant)
      move_in = parse_date(tenant["move_in_date"])
      confirmed = parse_date(tenant["confirmed_date"])

      opposing = if @base_right_date && move_in
        move_in < @base_right_date
      else
        false
      end

      has_priority = move_in.present? && confirmed.present?
      eff_date = has_priority ? [ move_in + 1.day, confirmed ].max : nil

      {
        "name" => tenant["name"],
        "deposit" => tenant["deposit"],
        "move_in_date" => tenant["move_in_date"],
        "confirmed_date" => tenant["confirmed_date"],
        "opposing_power" => opposing,
        "has_priority_repayment" => has_priority,
        "effective_date" => eff_date&.to_s,
        "priority_rank" => nil
      }
    end

    def assign_priority_ranks!(tenants)
      ranked = tenants
        .select { |t| t["has_priority_repayment"] }
        .sort_by { |t| t["effective_date"] }

      ranked.each_with_index { |t, i| t["priority_rank"] = i + 1 }
    end

    def calculate_amounts(validated_tenants)
      surviving = @rights_timeline.reject { |r| r["extinguished_on_sale"] }
      unevaluated, summable = surviving.partition do |r|
        UNEVALUATED_TYPES.include?(r["type"].to_s.gsub(/\s+/, ""))
      end

      assumed = summable.sum { |r| r["amount"].to_i }
      opposing_deposits = validated_tenants
        .select { |t| t["opposing_power"] }
        .sum { |t| t["deposit"].to_i }

      {
        "assumed_amount" => assumed,
        "opposing_deposits" => opposing_deposits,
        "total_risk_amount" => assumed + opposing_deposits,
        "unevaluated_rights" => unevaluated,
        "disclaimer" => unevaluated.empty? ? nil : "추정치이며, 별도 평가 필요 항목이 #{unevaluated.size}건 있습니다. 베테랑/공인중개사 검토를 권장합니다."
      }
    end

    def detect_discrepancies(originals, validated)
      originals.each_with_index.filter_map do |original, idx|
        llm_val = original["opposing_power"]
        ruby_val = validated[idx]["opposing_power"]

        next if llm_val == ruby_val

        move_in = original["move_in_date"]
        {
          "tenant_name" => original["name"],
          "field" => "opposing_power",
          "llm_value" => llm_val,
          "ruby_value" => ruby_val,
          "reason" => "move_in_date(#{move_in}) #{ruby_val ? '<' : '>='} base_right_date(#{@base_right_date})"
        }
      end
    end

    def parse_date(str)
      return nil if str.blank?
      Date.parse(str)
    rescue Date::Error
      nil
    end
  end
end
