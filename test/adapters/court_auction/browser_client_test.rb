require "test_helper"

class CourtAuction::BrowserClientTest < ActiveSupport::TestCase
  setup do
    @client = CourtAuction::BrowserClient.new(timeout: 5)
  end

  # -- price_label ---------------------------------------------------------

  test "price_label for 50_000_000 returns 5천만원" do
    assert_equal "5천만원", @client.send(:price_label, 50_000_000)
  end

  test "price_label for 100_000_000 returns 1억원" do
    assert_equal "1억원", @client.send(:price_label, 100_000_000)
  end

  test "price_label for 150_000_000 returns 1억5천만원" do
    assert_equal "1억5천만원", @client.send(:price_label, 150_000_000)
  end

  test "price_label for 500_000_000 returns 5억원" do
    assert_equal "5억원", @client.send(:price_label, 500_000_000)
  end

  test "price_label for 1_000_000_000 returns 10억원" do
    assert_equal "10억원", @client.send(:price_label, 1_000_000_000)
  end

  test "price_label for 10_000_000 returns 1천만원" do
    assert_equal "1천만원", @client.send(:price_label, 10_000_000)
  end

  # -- find_matching_item --------------------------------------------------

  test "find_matching_item matches exact case number" do
    items = [ { "srnSaNo" => "2024타경6008" } ]
    match = @client.send(:find_matching_item, items, year: "2024", type: "타경", number: "06008")
    assert_equal "2024타경6008", match["srnSaNo"]
  end

  test "find_matching_item matches zero-padded case number" do
    items = [ { "srnSaNo" => "2024타경06008" } ]
    match = @client.send(:find_matching_item, items, year: "2024", type: "타경", number: "6008")
    assert_equal "2024타경06008", match["srnSaNo"]
  end

  test "find_matching_item returns nil when no match" do
    items = [ { "srnSaNo" => "2024타경99999" } ]
    match = @client.send(:find_matching_item, items, year: "2024", type: "타경", number: "6008")
    assert_nil match
  end

  # -- escape_js -----------------------------------------------------------

  test "escape_js escapes single quotes" do
    assert_equal "O\\'Brien", @client.send(:escape_js, "O'Brien")
  end

  test "escape_js escapes backslashes" do
    assert_equal "path\\\\to", @client.send(:escape_js, 'path\\to')
  end
end
