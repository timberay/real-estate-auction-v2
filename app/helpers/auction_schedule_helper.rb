# frozen_string_literal: true

module AuctionScheduleHelper
  # Returns hash with :date, :dday_text, :dday_class, :dday_aria for the next
  # upcoming auction schedule of the given property, or nil when no future
  # schedule exists. Uses the `next_auction_schedule` has_one association so
  # callers can preload it (avoiding N+1 in list views).
  #
  # :dday_aria is intended for the badge's aria-label so screen readers say
  # "오늘 매각" / "매각 N일 전" instead of "D dash N".
  def next_auction_schedule_info(property)
    schedule = property.next_auction_schedule
    return nil unless schedule

    days = (schedule.schedule_date - Date.current).to_i
    dday_text = days.zero? ? "D-day" : "D-#{days}"
    dday_aria = days.zero? ? "오늘 매각" : "매각 #{days}일 전"
    dday_class = if days.zero?
      "bg-red-100 text-red-700 dark:bg-red-900/30 dark:text-red-300"
    elsif days <= 7
      "bg-amber-100 text-amber-700 dark:bg-amber-900/30 dark:text-amber-300"
    else
      "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300"
    end

    { date: schedule.schedule_date, dday_text: dday_text, dday_class: dday_class, dday_aria: dday_aria }
  end
end
