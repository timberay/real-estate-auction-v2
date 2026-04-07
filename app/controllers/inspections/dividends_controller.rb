module Inspections
  class DividendsController < ApplicationController
    def update
      @property = Property.find(params[:property_id])
      @report = RightsAnalysisReport.find_by!(property: @property, user: current_user)

      expected_bid = params[:expected_bid].present? ? params[:expected_bid].to_i : nil
      registry_data = @property.raw_data&.dig("registry_transcript")
      tenants = @report.report_data["tenants"]&.map(&:symbolize_keys) || []
      seizures = registry_data&.dig("seizures") || []
      rights = registry_data&.dig("rights") || []

      simulation = RightsAnalysis::DividendSimulator.call(
        rights: rights, tenants: tenants, seizures: seizures,
        expected_bid: expected_bid
      )

      report_data = @report.report_data.dup
      report_data["dividend_simulation"] = simulation.slice(:expected_bid, :distribution).deep_stringify_keys
      report_data["bidder_burden"] = simulation[:bidder_burden].deep_stringify_keys
      @report.update!(report_data: report_data)

      redirect_to property_inspections_grade_url(@property)
    end
  end
end
