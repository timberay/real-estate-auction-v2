# frozen_string_literal: true

module AuctionScheduleHelper
  # Returns hash with :schedule, :date, :dday_text, :dday_class for the next
  # upcoming auction schedule of the given property, or nil when no future
  # schedule exists.
  def next_auction_schedule_info(property)
    schedule = property.auction_schedules
      .where("schedule_date >= ?", Date.current)
      .order(:schedule_date)
      .first
    return nil unless schedule

    days = (schedule.schedule_date - Date.current).to_i
    dday_text = days.zero? ? "D-day" : "D-#{days}"
    dday_class = if days.zero?
      "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300"
    elsif days <= 7
      "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"
    else
      "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300"
    end

    { schedule: schedule, date: schedule.schedule_date, dday_text: dday_text, dday_class: dday_class }
  end
end
