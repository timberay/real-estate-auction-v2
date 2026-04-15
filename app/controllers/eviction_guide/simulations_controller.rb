module EvictionGuide
  class SimulationsController < ApplicationController
    def create
      property_id = params[:property_id].presence&.to_i

      @simulation = if property_id
        EvictionSimulation.find_or_initialize_by(property_id: property_id)
      else
        EvictionSimulation.new(session_id: session.id.to_s)
      end

      @simulation.answers = {}
      @simulation.result_path = []
      @simulation.completed = false
      @simulation.difficulty_level = nil
      @simulation.save!

      session[:eviction_simulation_id] = @simulation.id

      if @simulation.property_linked?
        redirect_to eviction_guide_simulator_prefill_path
      else
        redirect_to eviction_guide_simulator_question_path(code: "Q1")
      end
    end

    def update
      @simulation = find_simulation
      return head(:not_found) unless @simulation

      question_code = params[:question_code]
      answer = params[:answer] == "true"
      next_code = params[:next_code]

      @simulation.record_answer(question_code, answer)
      @simulation.save!

      if next_code == "END" || next_code.blank?
        redirect_to eviction_guide_simulation_path
      else
        redirect_to eviction_guide_simulator_question_path(code: next_code)
      end
    end

    def show
      @simulation = find_simulation
      return redirect_to eviction_guide_simulator_path unless @simulation

      @simulation.result_path = EvictionGuide::PathBuilder.call(@simulation.answers)
      @simulation.difficulty_level = EvictionGuide::DifficultyAssessor.call(@simulation.answers)
      @simulation.completed = true
      @simulation.save!

      render "eviction_guide/simulator/result", layout: "application"
    end

    def prefill
      @simulation = find_simulation
      return redirect_to eviction_guide_simulator_path unless @simulation&.property_linked?

      @property = @simulation.property
      @prefill_data = EvictionGuide::F02DataExtractor.call(@property)
      render "eviction_guide/simulator/prefill"
    end

    private

    def find_simulation
      EvictionSimulation.find_by(id: session[:eviction_simulation_id])
    end
  end
end
