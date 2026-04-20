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
      @requested_code = params[:code]
      @simulation = EvictionSimulation.find_by(id: session[:eviction_simulation_id])
      @resume_path = resume_path_for(@simulation)
      render "eviction_guide/simulator/question_not_found", status: :not_found
    end

    private

    def resume_path_for(simulation)
      return nil unless simulation

      last_answered = simulation.answers&.keys&.last
      if last_answered && EvictionSimulatorQuestion.exists?(code: last_answered)
        eviction_guide_simulator_question_path(code: last_answered)
      elsif simulation.occupant_type.present?
        first_code = EvictionSimulatorQuestion
          .for_occupant_type(simulation.occupant_type)
          .ordered.first&.code
        first_code ? eviction_guide_simulator_question_path(code: first_code) : eviction_guide_simulator_select_type_path
      elsif simulation.property_linked?
        eviction_guide_simulator_prefill_path
      else
        eviction_guide_simulator_select_type_path
      end
    end
  end
end
