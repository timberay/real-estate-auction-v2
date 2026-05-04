require "test_helper"

class CourtAuction::CaseNumberParserTest < ActiveSupport::TestCase
  test "parses 타경 case number" do
    result = CourtAuction::CaseNumberParser.parse("2024타경881")
    assert_equal "2024", result[:year]
    assert_equal "타경", result[:type]
    assert_equal "00881", result[:number]
  end

  test "parses 타채 case number (auction by application)" do
    result = CourtAuction::CaseNumberParser.parse("2026타채123")
    assert_equal "2026", result[:year]
    assert_equal "타채", result[:type]
    assert_equal "00123", result[:number]
  end

  test "strips whitespace before matching" do
    result = CourtAuction::CaseNumberParser.parse("  2024 타경 881  ")
    assert_equal "00881", result[:number]
  end

  test "preserves leading zeros via rjust(5)" do
    result = CourtAuction::CaseNumberParser.parse("2024타경7")
    assert_equal "00007", result[:number]
  end

  test "raises ParseError on invalid format" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse("hello")
    end
  end

  test "raises ParseError when 타경/타채 missing" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse("2024-881")
    end
  end

  test "raises ParseError on non-string input" do
    assert_raises(DataProvider::ParseError) do
      CourtAuction::CaseNumberParser.parse(nil)
    end
  end
end
