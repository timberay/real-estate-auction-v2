module Api
  class ReserveFundDefaultsController < ApplicationController
    def index
      defaults = ReserveFundDefault.where(property_type_id: params[:property_type_id])
                                   .order(:area_range_min)
      render json: defaults.select(
        :id, :area_range_min, :area_range_max, :repair_cost,
        :acquisition_tax_rate, :scrivener_fee, :moving_cost, :maintenance_fee
      )
    end
  end
end
