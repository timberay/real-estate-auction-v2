require "test_helper"

class AuctionScheduleTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    schedule = auction_schedules(:safe_apartment_schedule_1)
    assert schedule.valid?
  end

  test "invalid without schedule_date" do
    schedule = AuctionSchedule.new(property: properties(:safe_apartment))
    assert_not schedule.valid?
    assert_includes schedule.errors[:schedule_date], "can't be blank"
  end

  test "invalid with negative min_price" do
    schedule = auction_schedules(:safe_apartment_schedule_1)
    schedule.min_price = -1
    assert_not schedule.valid?
    assert_includes schedule.errors[:min_price], "must be greater than or equal to 0"
  end

  test "valid with nil min_price" do
    schedule = auction_schedules(:safe_apartment_schedule_1)
    schedule.min_price = nil
    assert schedule.valid?
  end
end
