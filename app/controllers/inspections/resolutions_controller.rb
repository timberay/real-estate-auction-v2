module Inspections
  class ResolutionsController < ApplicationController
    include PropertyScopable
    before_action :set_user_property

    def update
      @result = @property.inspection_results
        .where(user: current_user)
        .find(params[:result_id])

      unless @result.has_risk && (@result.auto? || @result.ai?)
        return head :unprocessable_entity
      end

      @result.update!(
        resolvable: params[:resolvable] == "true",
        resolution_note: params[:resolution_note]
      )

      InspectionRatingService.new(property: @property, user: current_user).call
      @active_tab = @result.inspection_item.tab

      respond_to do |format|
        format.turbo_stream
      end
    end
  end
end
