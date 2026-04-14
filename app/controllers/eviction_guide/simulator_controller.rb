module EvictionGuide
  class SimulatorController < ApplicationController
    def question
      @question = EvictionSimulatorQuestion.find_by!(code: params[:code])
      @simulation = EvictionSimulation.find_by(id: session[:eviction_simulation_id])
      @step = @question.step

      if turbo_frame_request?
        render partial: "eviction_guide/simulator/question"
      else
        render "eviction_guide/simulator/question"
      end
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
