module EvictionGuide
  class SimulatorQuestionComponent < ViewComponent::Base
    def initialize(question:, simulation:, step: nil)
      @question = question
      @simulation = simulation
      @step = step || question.step
    end

    private

    def progress_percent
      total = EvictionSimulatorQuestion.count
      answered = @simulation&.answers&.size || 0
      return 0 if total.zero?
      ((answered.to_f / total) * 100).round
    end
  end
end
