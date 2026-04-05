module Analyses
  class ResultsController < ApplicationController
    def edit
      @property = Property.find(params[:property_id])
      @results_by_axis = @property.property_check_results
        .includes(:checklist_item)
        .order("checklist_items.position")
        .group_by { |r| r.checklist_item.risk_axis }
    end

    def update
      @property = Property.find(params[:property_id])

      if params[:resolutions].present?
        params[:resolutions].each do |id, values|
          result = @property.property_check_results.find(id)
          result.update!(
            resolvable: values[:resolvable] == "true",
            resolution_note: values[:resolution_note]
          )
        end
      end

      redirect_to property_analyses_rating_url(@property)
    end
  end
end
