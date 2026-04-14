module EvictionGuide
  class SimulatorResultComponent < ViewComponent::Base
    def initialize(simulation:)
      @simulation = simulation
      @path = simulation.result_path || []
    end

    private

    def total_steps
      @path.size
    end

    def branch_count
      @path.count { |e| e["status"] == "branch" }
    end

    STATUS_BADGE = {
      "completed" => { label: "완료", classes: "bg-green-600 text-white" },
      "needed" => { label: "필요", classes: "bg-blue-600 text-white" },
      "branch" => { label: "분기", classes: "bg-red-600 text-white" }
    }.freeze

    def status_badge(status)
      STATUS_BADGE[status] || STATUS_BADGE["needed"]
    end
  end
end
