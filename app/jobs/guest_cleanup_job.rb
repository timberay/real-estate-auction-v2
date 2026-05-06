class GuestCleanupJob < ApplicationJob
  queue_as :default

  STALE_AFTER_DAYS = ENV.fetch("GUEST_STALE_AFTER_DAYS", 30).to_i

  def perform(threshold: STALE_AFTER_DAYS.days.ago)
    scope = User.where(guest: true).where("last_seen_at < ?", threshold)
    count = scope.count
    scope.find_each(&:destroy!)
    Rails.logger.info("[GuestCleanupJob] destroyed #{count} stale guests")
  end
end
