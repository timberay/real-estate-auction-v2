require "test_helper"

class Llm::MockTest < ActiveSupport::TestCase
  test "analyze returns parsed JSON hash with results key" do
    adapter = Llm::Mock.new
    response = adapter.analyze(system: "ignored", prompt: "ignored")
    assert_kind_of Hash, response
    assert response.key?("results"), "Response must have 'results' key"
  end

  test "response contains rights-002 item with required fields" do
    adapter = Llm::Mock.new
    response = adapter.analyze(system: "ignored", prompt: "ignored")
    item = response["results"]["rights-002"]
    assert_not_nil item
    assert_includes [true, false, nil], item["has_risk"]
    assert_includes %w[high medium none], item["confidence"]
    assert item["reasoning"].present?
  end

  test "response contains all rights_analysis items" do
    adapter = Llm::Mock.new
    response = adapter.analyze(system: "ignored", prompt: "ignored")
    rights_codes = InspectionItem.where(tab: :rights_analysis).pluck(:code)
    rights_codes.each do |code|
      assert response["results"].key?(code), "Missing item: #{code}"
    end
  end
end
