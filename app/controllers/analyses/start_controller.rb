module Analyses
  class StartController < ApplicationController
    def create
      @property = Property.find(params[:property_id])
      result = PropertyAnalysisService.call(property: @property, user: current_user)

      if result[:pending_manual_items].any?
        redirect_to edit_property_analyses_manual_input_url(@property)
      else
        redirect_to edit_property_analyses_result_url(@property)
      end
    end
  end
end
