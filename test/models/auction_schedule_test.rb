require "test_helper"

class AuctionScheduleTest < ActiveSupport::TestCase
  test "valid with required attributes" do
    schedule = auction_schedules(:safe_apartment_schedule_1)
    assert schedule.valid?
  end

  test "invalid without schedule_date" do
    schedule = AuctionSchedule.new(property: properties(:safe_apartment))
    assert_not schedule.valid?
    assert_includes schedule.errors[:schedule_date], "을(를) 입력해 주세요"
  end

  test "invalid with negative min_price" do
    schedule = auction_schedules(:safe_apartment_schedule_1)
    schedule.min_price = -1
    assert_not schedule.valid?
    assert_includes schedule.errors[:min_price], "은(는) 0 이상이어야 합니다"
  end

  test "valid with nil min_price" do
    schedule = auction_schedules(:safe_apartment_schedule_1)
    schedule.min_price = nil
    assert schedule.valid?
  end
end
