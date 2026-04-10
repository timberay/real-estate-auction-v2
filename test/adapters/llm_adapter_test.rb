require "test_helper"

class LlmAdapterTest < ActiveSupport::TestCase
  test "base class raises NotImplementedError on analyze" do
    adapter = LlmAdapter.new
    assert_raises(NotImplementedError) do
      adapter.analyze(system: "test", prompt: "test")
    end
  end

  test ".for returns MockLlmAdapter when USE_MOCK is true" do
    original = ENV["USE_MOCK"]
    ENV["USE_MOCK"] = "true"
    adapter = LlmAdapter.for
    assert_instance_of MockLlmAdapter, adapter
  ensure
    ENV["USE_MOCK"] = original
  end

  test ".for returns AnthropicLlmAdapter when USE_MOCK is not true" do
    original = ENV["USE_MOCK"]
    ENV["USE_MOCK"] = "false"
    adapter = LlmAdapter.for
    assert_instance_of AnthropicLlmAdapter, adapter
  ensure
    ENV["USE_MOCK"] = original
  end

  test "sanitize_and_parse_json strips markdown code block wrapper" do
    adapter = LlmAdapter.new
    raw = "```json\n{\"results\": {}}\n```"
    parsed = adapter.send(:sanitize_and_parse_json, raw)
    assert_equal({}, parsed["results"])
  end

  test "sanitize_and_parse_json handles plain JSON" do
    adapter = LlmAdapter.new
    raw = '{"results": {}}'
    parsed = adapter.send(:sanitize_and_parse_json, raw)
    assert_equal({}, parsed["results"])
  end
end
