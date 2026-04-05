module Analyses
  class RatingsController < ApplicationController
    def show
      @property = Property.find(params[:property_id])
      @rating = SafetyRatingService.call(property: @property)
      @risk_results = @property.property_check_results
        .where(has_risk: true)
        .includes(:checklist_item)
        .order("checklist_items.position")
    end
  end
end
