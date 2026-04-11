module Inspections
  class StartController < ApplicationController
    def create
      @property = Property.find(params[:property_id])
      redirect_to edit_property_inspections_tab_url(@property, tab_key: "rights_analysis")
    end
  end
end
