module EvictionGuide
  class StepsController < ApplicationController
    def show
      @step = EvictionStep.main.find_by!(code: params[:code])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
