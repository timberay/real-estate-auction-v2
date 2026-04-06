module Analyses
  class ManualInputsController < ApplicationController
    def edit
      @property = Property.find(params[:property_id])
      @pending_results = @property.property_check_results
        .where(source_type: nil, user: current_user)
        .includes(:checklist_item)
        .order("checklist_items.position")
    end

    def update
      @property = Property.find(params[:property_id])

      if params[:check_results].present?
        params[:check_results].each do |id, values|
          result = @property.property_check_results.where(user: current_user).find(id)
          result.update!(
            source_type: "manual",
            manual_value: values[:manual_value],
            has_risk: values[:has_risk] == "true"
          )
        end
      end

      redirect_to edit_property_analyses_result_url(@property)
    end
  end
end
