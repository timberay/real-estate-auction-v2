class EvictionSimulationCleanupJob < ApplicationJob
  queue_as :default

  def perform
    count = EvictionSimulation.stale.delete_all
    Rails.logger.info "[EvictionSimulationCleanupJob] Deleted #{count} stale simulations"
  end
end
