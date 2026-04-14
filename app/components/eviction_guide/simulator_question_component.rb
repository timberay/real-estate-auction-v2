module EvictionGuide
  class SimulatorQuestionComponent < ViewComponent::Base
    def initialize(question:, simulation:, step: nil)
      @question = question
      @simulation = simulation
      @step = step || question.step
    end

    private

    def progress_percent
      answered = @simulation&.answers&.size || 0
      remaining = count_remaining_steps(@question.code)
      total = answered + remaining
      return 0 if total.zero?
      ((answered.to_f / total) * 100).round
    end

    def count_remaining_steps(code, visited = Set.new)
      return 0 if code.blank? || code == "END" || visited.include?(code)
      visited.add(code)
      q = EvictionSimulatorQuestion.find_by(code: code)
      return 0 unless q
      1 + count_remaining_steps(q.yes_next_code, visited)
    end

    def yes_ends?
      @question.yes_next_code == "END" || @question.yes_next_code.blank?
    end

    def no_ends?
      @question.no_next_code == "END" || @question.no_next_code.blank?
    end
  end
end
