require "test_helper"

class RightsAnalysis::ExtinguishmentBaseRightExtractorTest < ActiveSupport::TestCase
  test "extracts earliest mortgage as base right" do
    registry_data = {
      "rights" => [
        { "type" => "근저당", "date" => "2024-03-01", "holder" => "우리은행", "amount" => 100_000_000 },
        { "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 }
      ]
    }
    result = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(registry_data)
    assert_equal "근저당", result[:type]
    assert_equal Date.parse("2024-01-15"), result[:date]
    assert_equal "국민은행", result[:holder]
  end

  test "extracts provisional seizure as base right when earliest" do
    registry_data = {
      "rights" => [
        { "type" => "가압류", "date" => "2023-06-01", "holder" => "채권추심회사", "amount" => 50_000_000 },
        { "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 }
      ]
    }
    result = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(registry_data)
    assert_equal "가압류", result[:type]
    assert_equal Date.parse("2023-06-01"), result[:date]
    assert_equal "채권추심회사", result[:holder]
  end

  test "considers only base-right-eligible types" do
    registry_data = {
      "rights" => [
        { "type" => "전세권", "date" => "2022-01-01", "holder" => "임차인", "amount" => 50_000_000 },
        { "type" => "근저당", "date" => "2024-01-15", "holder" => "국민은행", "amount" => 200_000_000 }
      ]
    }
    result = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(registry_data)
    assert_equal "근저당", result[:type]
    assert_equal Date.parse("2024-01-15"), result[:date]
  end

  test "returns nil when no eligible rights exist" do
    registry_data = { "rights" => [] }
    result = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(registry_data)
    assert_nil result
  end

  test "returns nil when registry data is nil" do
    result = RightsAnalysis::ExtinguishmentBaseRightExtractor.call(nil)
    assert_nil result
  end
end
