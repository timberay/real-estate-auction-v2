module Analyses
  class RatingsController < ApplicationController
    def show
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @active_step = :rating
      @rating = SafetyRatingService.call(property: @property, user: current_user)
      @risk_results = @property.property_check_results
        .where(has_risk: true, user: current_user)
        .includes(:checklist_item)
        .order("checklist_items.position")
    end
  end
end
