class GuestCleanupJob < ApplicationJob
  queue_as :default

  def perform(threshold: 30.days.ago)
    scope = User.where(guest: true).where("last_seen_at < ?", threshold)
    count = scope.count
    scope.find_each(&:destroy!)
    Rails.logger.info("[GuestCleanupJob] destroyed #{count} stale guests")
  end
end
