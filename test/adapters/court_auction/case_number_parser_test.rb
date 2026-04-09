# test/adapters/court_auction/case_number_parser_test.rb
require "test_helper"

class CourtAuction::CaseNumberParserTest < ActiveSupport::TestCase
  test "parses standard case number" do
    result = CourtAuction::CaseNumberParser.parse("2026타경10001")
    assert_equal "2026", result[:year]
    assert_equal "타경", result[:type]
    assert_equal "10001", result[:number]
  end

  test "parses case number with spaces" do
    result = CourtAuction::CaseNumberParser.parse("2026 타경 10001")
    assert_equal "2026", result[:year]
    assert_equal "타경", result[:type]
    assert_equal "10001", result[:number]
  end

  test "parses 타채 case type" do
    result = CourtAuction::CaseNumberParser.parse("2025타채5678")
    assert_equal "2025", result[:year]
    assert_equal "타채", result[:type]
    assert_equal "05678", result[:number]
  end

  test "zero-pads short case numbers" do
    result = CourtAuction::CaseNumberParser.parse("2026타경123")
    assert_equal "00123", result[:number]
  end

  test "raises ParseError for invalid format" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse("invalid")
    end
  end

  test "raises ParseError for empty string" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse("")
    end
  end

  test "raises ParseError for nil" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse(nil)
    end
  end
end
