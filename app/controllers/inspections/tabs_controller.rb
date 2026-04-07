module Inspections
  class TabsController < ApplicationController
    VALID_TABS = %w[ sale_document registry building_ledger online field_visit etc ].freeze

    def edit
      @property = Property.find(params[:property_id])
      @user_property = current_user.user_properties.find_by(property: @property)
      @tab_key = params[:tab_key]
      return head(:not_found) unless VALID_TABS.include?(@tab_key)

      @results = @property.inspection_results
        .where(user: current_user)
        .joins(:inspection_item)
        .where(inspection_items: { tab: InspectionItem.tabs[@tab_key] })
        .includes(:inspection_item)
        .order("inspection_items.tab_position")
    end

    def update
      @property = Property.find(params[:property_id])
      @tab_key = params[:tab_key]
      return head(:not_found) unless VALID_TABS.include?(@tab_key)

      if params[:resolutions].present?
        params[:resolutions].each do |id, values|
          result = @property.inspection_results.where(user: current_user).find(id)

          if result.auto?
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

      redirect_to edit_property_inspections_tab_url(@property, tab_key: @tab_key)
    end
  end
end
