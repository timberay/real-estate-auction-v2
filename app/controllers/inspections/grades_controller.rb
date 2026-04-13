module Inspections
  class GradesController < ApplicationController
    def show
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @rating = InspectionRatingService.call(property: @property, user: current_user)
      @report = RightsAnalysisReport.find_by(property: @property, user: current_user)
      @budget_setting = current_user.budget_setting

      @results_by_tab = @property.inspection_results
        .where(user: current_user)
        .includes(:inspection_item)
        .group_by { |r| r.inspection_item.tab }

      @risk_results = @property.inspection_results
        .where(has_risk: true, user: current_user)
        .includes(:inspection_item)
        .order("inspection_items.tab, inspection_items.tab_position")
    end
  end
end
