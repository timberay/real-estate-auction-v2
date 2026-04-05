class PropertiesController < ApplicationController
  def index
    @properties = Property.all.order(created_at: :desc)
    @properties = @properties.where(safety_rating: params[:safety_rating]) if params[:safety_rating].present?
  end

  def show
    @property = Property.find(params[:id])
    @check_results = @property.property_check_results.includes(:checklist_item).order("checklist_items.position")
  end
end
