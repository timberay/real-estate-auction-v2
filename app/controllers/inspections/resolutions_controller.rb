module Inspections
  class ResolutionsController < ApplicationController
    include PropertyScopable
    before_action :set_user_property

    def update
      @result = @property.inspection_results
        .where(user: current_user)
        .find(params[:result_id])

      return head(:unprocessable_entity) unless apply_update

      InspectionRatingService.new(property: @property, user: current_user).call
      @active_tab = @result.inspection_item.tab

      respond_to do |format|
        format.turbo_stream
      end
    end

    private

    def apply_update
      if params.key?(:has_risk)
        apply_manual_answer
      elsif params.key?(:resolvable)
        apply_resolution
      end
    end

    def apply_manual_answer
      return false if @result.auto?
      return false if @result.ai? && !@result.has_risk.nil?

      has_risk = params[:has_risk] == "true"
      attrs = { source_type: "manual", has_risk: has_risk }

      if has_risk
        attrs[:resolvable] = params[:resolvable] == "true" if %w[true false].include?(params[:resolvable])
        attrs[:resolution_note] = params[:resolution_note] if params.key?(:resolution_note)
      else
        attrs[:resolvable] = nil
        attrs[:resolution_note] = nil
      end

      @result.update!(attrs)
      true
    end

    def apply_resolution
      return false unless @result.has_risk && (@result.auto? || @result.ai?)

      @result.update!(
        resolvable: params[:resolvable] == "true",
        resolution_note: params[:resolution_note]
      )
      true
    end
  end
end
