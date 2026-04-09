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

  # --- format_price_won ---

  test "format_price_won converts won to eok" do
    assert_equal "8억", format_price_won(800000000)
  end

  test "format_price_won converts won with remainder" do
    assert_equal "5억 6,000만원", format_price_won(560000000)
  end

  test "format_price_won converts won below 1 eok" do
    assert_equal "5,000만원", format_price_won(50000000)
  end

  test "format_price_won returns dash for nil" do
    assert_equal "—", format_price_won(nil)
  end
end
