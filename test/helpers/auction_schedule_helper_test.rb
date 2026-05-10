# frozen_string_literal: true

require "test_helper"

class AuctionScheduleHelperTest < ActionView::TestCase
  setup do
    # Pin the clock so D-N strings stay stable regardless of when tests run
    # (avoids UTC-midnight flakiness).
    travel_to Time.zone.local(2026, 5, 10, 12, 0, 0)
    @property = properties(:safe_apartment)
    @property.auction_schedules.delete_all
  end

  teardown do
    travel_back
  end

  test "returns nil when property has no auction schedules" do
    assert_nil next_auction_schedule_info(@property)
  end

  test "returns nil when only past schedules exist" do
    @property.auction_schedules.create!(schedule_date: Date.current - 1.day, schedule_time: "1000")
    assert_nil next_auction_schedule_info(@property)
  end

  test "returns D-day with red class when schedule is today" do
    schedule = @property.auction_schedules.create!(schedule_date: Date.current, schedule_time: "1000")
    info = next_auction_schedule_info(@property)
    assert_equal schedule.schedule_date, info[:date]
    assert_equal "D-day", info[:dday_text]
    assert_equal "오늘 매각", info[:dday_aria]
    assert_includes info[:dday_class], "bg-red-100"
    assert_includes info[:dday_class], "text-red-700"
  end

  test "returns D-3 with amber class when schedule is 3 days away" do
    @property.auction_schedules.create!(schedule_date: Date.current + 3.days, schedule_time: "1000")
    info = next_auction_schedule_info(@property)
    assert_equal "D-3", info[:dday_text]
    assert_equal "매각 3일 전", info[:dday_aria]
    assert_includes info[:dday_class], "bg-amber-100"
  end

  test "returns D-7 with amber class at the 7-day boundary" do
    @property.auction_schedules.create!(schedule_date: Date.current + 7.days, schedule_time: "1000")
    info = next_auction_schedule_info(@property)
    assert_equal "D-7", info[:dday_text]
    assert_includes info[:dday_class], "bg-amber-100"
  end

  test "returns D-30 with slate class when schedule is far in the future" do
    @property.auction_schedules.create!(schedule_date: Date.current + 30.days, schedule_time: "1000")
    info = next_auction_schedule_info(@property)
    assert_equal "D-30", info[:dday_text]
    assert_includes info[:dday_class], "bg-slate-100"
  end

  test "returns the earliest future schedule when multiple exist" do
    @property.auction_schedules.create!(schedule_date: Date.current + 14.days, schedule_time: "1000")
    @property.auction_schedules.create!(schedule_date: Date.current + 5.days, schedule_time: "1000")
    info = next_auction_schedule_info(@property)
    assert_equal Date.current + 5.days, info[:date]
    assert_equal "D-5", info[:dday_text]
  end

  test "ignores past schedules even when future ones exist" do
    @property.auction_schedules.create!(schedule_date: Date.current - 30.days, schedule_time: "1000")
    @property.auction_schedules.create!(schedule_date: Date.current + 10.days, schedule_time: "1000")
    info = next_auction_schedule_info(@property)
    assert_equal Date.current + 10.days, info[:date]
  end
end
