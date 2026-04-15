module EvictionGuide
  class SimulationsController < ApplicationController
    def create
      property_id = params[:property_id].presence&.to_i
      occupant_type = params[:occupant_type].presence
      occupant_type = nil unless EvictionSimulation::OCCUPANT_TYPES.include?(occupant_type)

      @simulation = if property_id
        EvictionSimulation.find_or_initialize_by(property_id: property_id)
      else
        EvictionSimulation.new(session_id: session.id.to_s)
      end

      @simulation.answers = {}
      @simulation.result_path = []
      @simulation.completed = false
      @simulation.difficulty_level = nil
      @simulation.occupant_type = occupant_type
      @simulation.save!

      session[:eviction_simulation_id] = @simulation.id

      if @simulation.property_linked?
        redirect_to eviction_guide_simulator_prefill_path
      elsif occupant_type.blank?
        redirect_to eviction_guide_simulator_select_type_path
      else
        redirect_to eviction_guide_simulator_question_path(code: first_question_code(occupant_type))
      end
    end

    def select_type
      @simulation = find_simulation || EvictionSimulation.new
      render "eviction_guide/simulator/select_type"
    end

    def update
      @simulation = find_simulation
      return head(:not_found) unless @simulation

      # Handle occupant_type selection from select_type page
      if params[:occupant_type].present?
        occupant_type = params[:occupant_type]
        return redirect_to eviction_guide_simulator_select_type_path unless EvictionSimulation::OCCUPANT_TYPES.include?(occupant_type)

        @simulation.occupant_type = occupant_type
        @simulation.save!
        return redirect_to eviction_guide_simulator_question_path(code: first_question_code(occupant_type))
      end

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

      @simulation.result_path = EvictionGuide::PathBuilder.call(@simulation.answers, occupant_type: @simulation.occupant_type)
      @simulation.difficulty_level = EvictionGuide::DifficultyAssessor.call(@simulation.answers, occupant_type: @simulation.occupant_type)
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

    def first_question_code(occupant_type)
      EvictionSimulatorQuestion.for_occupant_type(occupant_type).ordered.first&.code || "Q1"
    end
  end
end
