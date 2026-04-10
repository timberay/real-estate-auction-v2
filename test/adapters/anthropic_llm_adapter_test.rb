require "test_helper"

class AnthropicLlmAdapterTest < ActiveSupport::TestCase
  test "raises NotImplementedError with helpful message" do
    adapter = AnthropicLlmAdapter.new
    error = assert_raises(NotImplementedError) do
      adapter.analyze(system: "test", prompt: "test")
    end
    assert_match(/API key/, error.message)
  end
end
