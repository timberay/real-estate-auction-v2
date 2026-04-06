module Analyses
  class ResultsController < ApplicationController
    def edit
      @property = Property.find(params[:property_id])
      @results_by_axis = @property.property_check_results
        .where(user: current_user)
        .includes(:checklist_item)
        .order("checklist_items.position")
        .group_by { |r| r.checklist_item.risk_axis }
    end

    def update
      @property = Property.find(params[:property_id])

      if params[:resolutions].present?
        params[:resolutions].each do |id, values|
          result = @property.property_check_results.where(user: current_user).find(id)

          if result.source_type == "auto"
            result.update!(
              resolvable: values[:resolvable] == "true",
              resolution_note: values[:resolution_note]
            )
          else
            has_risk = values[:has_risk] == "true"
            attrs = { source_type: "manual", has_risk: has_risk }

            if has_risk
              attrs[:resolvable] = values[:resolvable] == "true"
              attrs[:resolution_note] = values[:resolution_note]
            else
              attrs[:resolvable] = nil
              attrs[:resolution_note] = nil
            end

            result.update!(attrs)
          end
        end
      end

      redirect_to property_analyses_rating_url(@property)
    end
  end
end
