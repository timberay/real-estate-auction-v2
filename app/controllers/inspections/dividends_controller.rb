module Inspections
  class DividendsController < ApplicationController
    include PropertyScopable
    before_action :set_user_property

    def update
      @report = RightsAnalysisReport.find_by!(property: @property, user: current_user)

      expected_bid = params[:expected_bid].to_i
      return redirect_to property_inspections_grade_url(@property) if expected_bid <= 0

      simulation = calculate_distribution(expected_bid)

      report_data = parsed_report_data.dup
      report_data["user_simulation"] = simulation
      @report.update!(report_data: report_data)

      redirect_to property_inspections_grade_url(@property)
    end

    private

    def parsed_report_data
      data = @report.report_data
      data.is_a?(String) ? JSON.parse(data) : (data || {})
    rescue JSON::ParserError
      {}
    end

    def calculate_distribution(expected_bid)
      execution_cost = (expected_bid * 0.015).to_i
      remaining = expected_bid - execution_cost

      distribution = []
      distribution << build_row(1, "집행비용", "집행비용", execution_cost, execution_cost)

      data = parsed_report_data
      rights = data.dig("llm_raw", "rights_timeline") || data["rights_timeline"] || []
      tenants = data.dig("calculated", "tenants") || data["tenants"] || []

      claimants = build_claimants(rights, tenants)
      claimants.sort_by! { |c| c[:priority_rank] }

      bidder_burden = 0

      claimants.each.with_index(2) do |claimant, rank|
        if claimant[:extinguished_on_sale]
          dividend = [ claimant[:amount], remaining ].min
          remaining -= dividend
          shortfall = claimant[:amount] - dividend
          distribution << build_row(rank, claimant[:holder], claimant[:type], claimant[:amount], dividend, shortfall)
        else
          bidder_burden += claimant[:amount]
          distribution << build_row(rank, claimant[:holder], claimant[:type], claimant[:amount], 0, 0, assumed: true)
        end
      end

      {
        "expected_bid" => expected_bid,
        "execution_cost" => execution_cost,
        "distribution" => distribution,
        "bidder_burden" => bidder_burden,
        "remaining" => remaining,
        "simulated_at" => Time.current.iso8601
      }
    end

    def build_claimants(rights, tenants)
      claimants = rights.map.with_index(1) do |right, idx|
        {
          holder: right["holder"],
          type: right["type"],
          amount: right["amount"].to_i,
          priority_rank: idx,
          extinguished_on_sale: right["extinguished_on_sale"]
        }
      end

      tenants.select { |t| t["opposing_power"] }.each do |tenant|
        claimants << {
          holder: tenant["name"],
          type: "임차보증금",
          amount: tenant["deposit"].to_i,
          priority_rank: tenant["priority_rank"] || 999,
          extinguished_on_sale: false
        }
      end

      claimants
    end

    def build_row(priority, holder, type, claim, dividend, shortfall = 0, assumed: false)
      {
        "priority" => priority,
        "holder" => holder,
        "type" => type,
        "claim" => claim,
        "dividend" => dividend,
        "shortfall" => shortfall,
        "assumed" => assumed
      }
    end
  end
end
