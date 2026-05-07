module Inspections
  class TabsController < ApplicationController
    include PropertyScopable
    before_action :set_user_property

    VALID_TABS = %w[ rights_analysis profit_analysis field_check bidding ].freeze

    def edit
      @tab_key = params[:tab_key]
      return head(:not_found) unless VALID_TABS.include?(@tab_key)

      all_results = @property.inspection_results
        .where(user: current_user)
        .includes(:inspection_item)
      answered_context = all_results.index_by { |r| r.inspection_item.code }
      all_items_by_code = all_results.map(&:inspection_item).index_by(&:code)

      property_type = @property.property_type

      tab_results = all_results
        .select { |r| r.inspection_item.tab == @tab_key }
        .select { |r| r.inspection_item.applicable_for?(property_type) }
        .sort_by { |r| r.inspection_item.tab_position }

      @dependency_hidden_ids = tab_results
        .select { |r| r.inspection_item.skip_for?(answered_context, all_items_by_code: all_items_by_code) }
        .map(&:id).to_set

      @results = tab_results
    end

    def update
      @tab_key = params[:tab_key]
      return head(:not_found) unless VALID_TABS.include?(@tab_key)

      if params[:resolutions].present?
        resolution_ids = params[:resolutions].keys
        results_by_id = @property.inspection_results
          .where(user: current_user, id: resolution_ids)
          .index_by(&:id)

        params[:resolutions].each do |id, values|
          result = results_by_id[id.to_i]
          next unless result

          if values[:override] == "true" && result.auto?
            apply_override(result, values)
          elsif result.auto? || result.ai?
            next unless values.key?(:resolvable)

            result.update!(
              resolvable: values[:resolvable] == "true",
              resolution_note: values[:resolution_note]
            )
          else
            apply_manual_input(result, values)
          end
        end
      end

      rating_service = InspectionRatingService.new(property: @property, user: current_user)
      rating_service.call

      tab_rating_value = rating_service.tab_rating(@tab_key)

      all_results_for_count = @property.inspection_results
        .where(user: current_user)
        .includes(:inspection_item)
      answered_context = all_results_for_count.index_by { |r| r.inspection_item.code }
      all_items_by_code = all_results_for_count.map(&:inspection_item).index_by(&:code)
      property_type = @property.property_type

      visible_tab_results = all_results_for_count
        .select { |r| r.inspection_item.tab == @tab_key }
        .select { |r| r.inspection_item.visible_for?(property_type: property_type, answered_results: answered_context, all_items_by_code: all_items_by_code) }
      unanswered_count = visible_tab_results.count { |r| r.has_risk.nil? }

      tab_label = TabSummaryTableComponent::TAB_LABELS[@tab_key] || @tab_key

      flash[:tab_rating] = {
        "rating" => tab_rating_value.to_s,
        "label" => tab_label,
        "unanswered_count" => unanswered_count
      }

      redirect_to edit_property_inspections_tab_url(@property, tab_key: @tab_key, anchor: "top")
    end

    private

    def apply_override(result, values)
      has_risk = values[:has_risk] == "true"
      attrs = {
        auto_value: result.has_risk.to_s,
        source_type: "manual",
        has_risk: has_risk
      }

      if has_risk
        attrs[:resolvable] = values[:resolvable] == "true"
        attrs[:resolution_note] = values[:resolution_note]
      else
        attrs[:resolvable] = nil
        attrs[:resolution_note] = nil
      end

      result.update!(attrs)
    end

    def apply_manual_input(result, values)
      return unless values.key?(:has_risk)

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
