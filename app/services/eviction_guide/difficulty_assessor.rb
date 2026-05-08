module EvictionGuide
  class DifficultyAssessor
    LEVELS = { "high" => 3, "medium" => 2, "low" => 1 }.freeze
    LEVEL_FROM_SCORE = LEVELS.invert.freeze

    Result = Struct.new(:level, :base, :triggers, keyword_init: true) do
      def to_s = level
    end

    def self.call(answers, occupant_type: nil, questions: nil)
      new(answers, occupant_type, questions).call
    end

    def initialize(answers, occupant_type = nil, questions = nil)
      @answers = answers || {}
      @occupant_type = occupant_type
      @questions = questions || load_questions
    end

    def call
      base_level = EvictionSimulation::BASE_DIFFICULTY[@occupant_type]
      base_score = LEVELS[base_level] || 0
      max_score = base_score

      triggers = []
      @answers.each do |code, answer|
        next if answer # only "no" answers trigger difficulty
        question = @questions[code]
        next unless question
        impact = question.respond_to?(:difficulty_impact) ? question.difficulty_impact : question[:difficulty_impact]
        next unless impact

        score = LEVELS[impact] || 0
        max_score = score if score > max_score

        triggers << build_trigger(question, impact)
      end

      Result.new(
        level: LEVEL_FROM_SCORE[max_score] || "low",
        base: { level: base_level, occupant_type: @occupant_type },
        triggers: triggers
      )
    end

    private

    def build_trigger(question, impact)
      step_code = question_value(question, :step_code)
      {
        code: question_value(question, :code),
        step_code: step_code,
        step_name: step_name_for(step_code),
        impact: impact,
        help_text: question_value(question, :help_text)
      }
    end

    def question_value(question, key)
      question.respond_to?(key) ? question.public_send(key) : question[key]
    end

    def step_name_for(step_code)
      steps[step_code]&.name || step_code
    end

    def steps
      @steps ||= EvictionStep.where(code: trigger_step_codes).index_by(&:code)
    end

    def trigger_step_codes
      @answers.filter_map do |code, answer|
        next if answer
        question = @questions[code]
        next unless question
        impact = question.respond_to?(:difficulty_impact) ? question.difficulty_impact : question[:difficulty_impact]
        next unless impact
        question_value(question, :step_code)
      end.uniq
    end

    def load_questions
      EvictionSimulatorQuestion.for_occupant_type(@occupant_type).index_by(&:code)
    end
  end
end
