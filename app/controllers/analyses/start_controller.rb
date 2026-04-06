module Analyses
  class StartController < ApplicationController
    def create
      @property = Property.find(params[:property_id])
      PropertyAnalysisService.call(property: @property, user: current_user)
      redirect_to edit_property_analyses_checklist_url(@property)
    end
  end
end
