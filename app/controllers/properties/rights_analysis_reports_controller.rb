module Properties
  class RightsAnalysisReportsController < ApplicationController
    include PropertyScopable

    before_action :set_user_property
    before_action :set_report

    def show_base_right_date
      render partial: "properties/rights_analysis_reports/base_right_date",
             locals: { report: @report, property: @property }
    end

    def edit_base_right_date
      render partial: "properties/rights_analysis_reports/edit_base_right_date_form",
             locals: { report: @report, property: @property }
    end

    def update_base_right_date
      new_date = base_right_date_params[:base_right_date]

      if new_date.present?
        @report.update!(base_right_date: new_date)
      end

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "base-right-date",
            partial: "properties/rights_analysis_reports/base_right_date",
            locals: { report: @report, property: @property }
          )
        end
        format.html { redirect_to property_path(@property) }
      end
    end

    private

    def set_report
      @report = RightsAnalysisReport.find_by!(user: current_user, property: @property)
    rescue ActiveRecord::RecordNotFound
      render plain: "Not Found", status: :not_found
    end

    def base_right_date_params
      params.require(:rights_analysis_report).permit(:base_right_date)
    end
  end
end
