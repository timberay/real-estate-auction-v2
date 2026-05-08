module EvictionGuide
  class PathBuilder
    def self.call(answers, occupant_type: nil)
      new(answers, occupant_type).call
    end

    def initialize(answers, occupant_type = nil)
      @answers = answers || {}
      @questions = questions_for(occupant_type).index_by(&:code)
      @steps = steps_for(occupant_type).index_by(&:code)
    end

    def call
      return [] if @answers.empty?

      path = []
      visited_steps = Set.new

      @answers.each do |code, answer|
        question = @questions[code]
        next unless question

        step = @steps[question.step_code]
        next unless step
        next if visited_steps.include?(step.code)

        visited_steps << step.code

        if answer
          path << { code: step.code, name: step.name, status: "completed" }
        else
          path << { code: step.code, name: step.name, status: "needed" }
          add_branch_to_path(path, question, visited_steps)
        end
      end

      path
    end

    private

    # Falls back to generic (nil occupant_type) records when no records exist
    # for the requested occupant_type — covers types with no seeded data yet.
    def questions_for(occupant_type)
      scoped = EvictionSimulatorQuestion.for_occupant_type(occupant_type)
      scoped.exists? ? scoped : EvictionSimulatorQuestion.for_occupant_type(nil)
    end

    def steps_for(occupant_type)
      scoped = EvictionStep.for_occupant_type(occupant_type)
      scoped.exists? ? scoped : EvictionStep.for_occupant_type(nil)
    end

    def add_branch_to_path(path, question, visited_steps)
      next_code = question.no_next_code
      return unless next_code && next_code != "END"

      next_q = @questions[next_code]
      return unless next_q

      branch_step = @steps[next_q.step_code]
      return unless branch_step&.branch?
      return if visited_steps.include?(branch_step.code)

      visited_steps << branch_step.code
      path << {
        code: branch_step.code,
        name: branch_step.name,
        status: "branch",
        return_step: branch_step.return_step_code
      }
    end
  end
end
