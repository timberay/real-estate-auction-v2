module Properties
  class RightsAnalysisReportsController < ApplicationController
    include PropertyScopable

    before_action :set_user_property
    before_action :set_report

    def update_base_right_date
    end

    private

    def set_report
      @report = RightsAnalysisReport.find_by!(user: current_user, property: @property)
    end

    def base_right_date_params
      params.require(:rights_analysis_report).permit(:base_right_date)
    end
  end
end
