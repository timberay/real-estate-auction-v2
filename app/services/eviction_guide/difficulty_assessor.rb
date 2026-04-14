module EvictionGuide
  class DifficultyAssessor
    LEVELS = { "high" => 3, "medium" => 2, "low" => 1 }.freeze
    LEVEL_FROM_SCORE = LEVELS.invert.freeze

    def self.call(answers, questions: nil)
      new(answers, questions).call
    end

    def initialize(answers, questions = nil)
      @answers = answers || {}
      @questions = questions || load_questions
    end

    def call
      max_score = 0

      @answers.each do |code, answer|
        next if answer # only "no" answers trigger difficulty
        question = @questions[code]
        next unless question
        impact = question.respond_to?(:difficulty_impact) ? question.difficulty_impact : question[:difficulty_impact]
        next unless impact
        score = LEVELS[impact] || 0
        max_score = score if score > max_score
      end

      LEVEL_FROM_SCORE[max_score] || "low"
    end

    private

    def load_questions
      EvictionSimulatorQuestion.all.index_by(&:code)
    end
  end
end
