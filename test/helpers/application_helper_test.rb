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

  # --- inspection_item_total ---

  test "inspection_item_total returns InspectionItem.count" do
    assert_equal InspectionItem.count, inspection_item_total
  end

  test "inspection_item_total memoizes within a single helper context" do
    call_count = 0
    with_stubbed_count(-> { call_count += 1; 99 }) do
      inspection_item_total
      inspection_item_total
    end
    assert_equal 1, call_count, "expected InspectionItem.count to be invoked exactly once across two calls"
  end

  test "inspection_item_total returns fresh values across separate helper contexts" do
    klass = Class.new { include ApplicationHelper }
    with_stubbed_count(5) { assert_equal 5, klass.new.send(:inspection_item_total) }
    with_stubbed_count(7) { assert_equal 7, klass.new.send(:inspection_item_total) }
  end

  private

  # Lightweight singleton-method stub for InspectionItem.count.
  # Minitest 6 dropped minitest/mock, so we roll our own. The base
  # .count is inherited from ActiveRecord::Querying, so defining a
  # singleton method shadows it; removing the singleton method
  # restores the original lookup.
  def with_stubbed_count(value_or_proc)
    sc = InspectionItem.singleton_class
    sc.send(:define_method, :count) do
      value_or_proc.respond_to?(:call) ? value_or_proc.call : value_or_proc
    end
    yield
  ensure
    sc.send(:remove_method, :count) if sc.instance_methods(false).include?(:count)
  end
end
