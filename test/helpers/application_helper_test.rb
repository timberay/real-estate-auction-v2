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
end
