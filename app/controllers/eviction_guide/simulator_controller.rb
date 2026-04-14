module EvictionGuide
  class SimulatorController < ApplicationController
    def question
      @question = EvictionSimulatorQuestion.find_by!(code: params[:code])
      @simulation = EvictionSimulation.find_by(id: session[:eviction_simulation_id])
      @step = @question.step
      render partial: "eviction_guide/simulator/question"
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
