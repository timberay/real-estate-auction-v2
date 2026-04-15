module EvictionGuide
  class OccupantTypeSelectorComponent < ViewComponent::Base
    CARDS = EvictionSimulation::OCCUPANT_TYPES.map { |type|
      {
        type: type,
        label: EvictionSimulation::OCCUPANT_TYPE_LABELS[type],
        difficulty: EvictionSimulation::BASE_DIFFICULTY[type]
      }
    }.freeze

    def initialize(simulation:)
      @simulation = simulation
    end

    private

    def cards
      CARDS
    end

    def difficulty_classes(level)
      case level
      when "low" then "bg-green-200 text-green-800 dark:bg-green-900/30 dark:text-green-400"
      when "medium" then "bg-yellow-200 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400"
      when "high" then "bg-red-200 text-red-800 dark:bg-red-900/30 dark:text-red-400"
      end
    end

    def difficulty_label(level)
      { "low" => "낮음", "medium" => "중간", "high" => "높음" }[level]
    end
  end
end
