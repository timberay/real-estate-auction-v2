module EvictionGuide
  class SimulatorQuestionComponent < ViewComponent::Base
    def initialize(question:, simulation:, step: nil)
      @question = question
      @simulation = simulation
      @step = step || question.step
    end

    private

    def occupant_type_label
      @simulation&.occupant_type_label
    end

    def progress_percent
      answered = @simulation&.answers&.size || 0
      total_main = EvictionStep
        .for_occupant_type(@simulation&.occupant_type)
        .main
        .count
      return 0 if total_main.zero?
      [ ((answered.to_f / total_main) * 100).round, 100 ].min
    end

    def yes_ends?
      @question.yes_next_code == "END" || @question.yes_next_code.blank?
    end

    def no_ends?
      @question.no_next_code == "END" || @question.no_next_code.blank?
    end
  end
end
