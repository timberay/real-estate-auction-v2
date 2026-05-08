module EvictionGuide
  class DifficultyAssessor
    LEVELS = { "high" => 3, "medium" => 2, "low" => 1 }.freeze
    LEVEL_FROM_SCORE = LEVELS.invert.freeze

    Result = Struct.new(:level, keyword_init: true) do
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
      base_score = LEVELS[EvictionSimulation::BASE_DIFFICULTY[@occupant_type]] || 0
      max_score = base_score

      @answers.each do |code, answer|
        next if answer
        question = @questions[code]
        next unless question
        impact = question.respond_to?(:difficulty_impact) ? question.difficulty_impact : question[:difficulty_impact]
        next unless impact
        score = LEVELS[impact] || 0
        max_score = score if score > max_score
      end

      level = LEVEL_FROM_SCORE[max_score] || "low"
      Result.new(level: level)
    end

    private

    def load_questions
      EvictionSimulatorQuestion.for_occupant_type(@occupant_type).index_by(&:code)
    end
  end
end
