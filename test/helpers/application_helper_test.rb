# frozen_string_literal: true

require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  # --- format_price_in_eok ---

  test "formats amount below 10000 as manwon" do
    assert_equal "5,000만원", format_price_in_eok(5000)
  end

  test "formats exact 10000 as 1억" do
    assert_equal "1억", format_price_in_eok(10000)
  end

  test "formats amount above 10000 with eok and manwon" do
    assert_equal "1억 2,000만원", format_price_in_eok(12000)
  end

  test "formats large amount with multiple eok" do
    assert_equal "8억", format_price_in_eok(80000)
  end

  test "formats large amount with eok and remainder" do
    assert_equal "8억 5,600만원", format_price_in_eok(85600)
  end

  test "returns dash for nil" do
    assert_equal "—", format_price_in_eok(nil)
  end

  test "returns dash for zero" do
    assert_equal "—", format_price_in_eok(0)
  end

  test "formats small amount without eok" do
    assert_equal "500만원", format_price_in_eok(500)
  end

  # --- appraisal_limits_by_round ---

  test "returns empty array when rounds is 0" do
    assert_equal [], appraisal_limits_by_round(10000, 0)
  end

  test "returns 1 entry for 1 round" do
    # 10000 / 0.8 = 12500
    assert_equal [ { round: 1, limit: 12500 } ], appraisal_limits_by_round(10000, 1)
  end

  test "returns entries for multiple rounds" do
    # round 1: 10000 / 0.8 = 12500
    # round 2: 10000 / 0.64 = 15625
    result = appraisal_limits_by_round(10000, 2)
    assert_equal 2, result.length
    assert_equal({ round: 1, limit: 12500 }, result[0])
    assert_equal({ round: 2, limit: 15625 }, result[1])
  end

  test "floors fractional results" do
    # 9620 / 0.8 = 12025.0
    # 9620 / 0.64 = 15031.25 → 15031
    result = appraisal_limits_by_round(9620, 2)
    assert_equal 12025, result[0][:limit]
    assert_equal 15031, result[1][:limit]
  end

  test "returns empty array when max_bid is nil" do
    assert_equal [], appraisal_limits_by_round(nil, 2)
  end
end
