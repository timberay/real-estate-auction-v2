module Inspections
  class DividendsController < ApplicationController
    def update
      @property = Property.find(params[:property_id])
      @report = RightsAnalysisReport.find_by!(property: @property, user: current_user)

      expected_bid = params[:expected_bid].present? ? params[:expected_bid].to_i : nil
      tenants = @report.report_data["tenants"]&.map(&:symbolize_keys) || []

      report_data = @report.report_data.dup
      report_data["dividend_simulation"] = { "expected_bid" => expected_bid, "distribution" => [] }
      report_data["bidder_burden"] = {}
      @report.update!(report_data: report_data)

      redirect_to property_inspections_grade_url(@property)
    end
  end
end
