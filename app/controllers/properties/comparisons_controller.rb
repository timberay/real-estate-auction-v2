# frozen_string_literal: true

module Properties
  class ComparisonsController < ApplicationController
    MAX_COMPARE = 10

    def show
      ids = Array(params[:ids].to_s.split(",")).map(&:to_i).reject(&:zero?).first(MAX_COMPARE)

      @user_properties = current_user.user_properties
        .joins(:property)
        .includes(property: :next_auction_schedule)
        .where(property_id: ids)

      if @user_properties.size < 2
        redirect_to properties_path, alert: "비교하려면 2개 이상의 물건을 선택해주세요."
        return
      end

      # Re-sort in Ruby to preserve the user's original selection order
      id_index = ids.each_with_index.to_h
      @user_properties = @user_properties.sort_by { |up| id_index[up.property_id] || Float::INFINITY }

      @reports_by_property = RightsAnalysisReport
        .where(user: current_user, property_id: @user_properties.map(&:property_id))
        .index_by(&:property_id)

      item_cache = InspectionRatingService.build_item_cache
      @ratings_by_property = @user_properties.each_with_object({}) do |up, h|
        h[up.property_id] = InspectionRatingService.new(
          property: up.property, user: current_user, item_cache: item_cache
        ).overall_rating
      end

      respond_to do |format|
        format.html
        format.csv { send_comparison_csv }
      end
    end

    private

    def send_comparison_csv
      csv_data = Export::ComparisonCsvExporter.new(user_properties: @user_properties, user: current_user).to_csv
      filename = "물건비교_#{@user_properties.size}건_#{Date.current}.csv"
      send_data csv_data, filename: filename, type: "text/csv; charset=utf-8", disposition: "attachment"
    end
  end
end
