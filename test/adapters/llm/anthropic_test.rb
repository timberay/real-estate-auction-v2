require "test_helper"

class Llm::AnthropicTest < ActiveSupport::TestCase
  setup do
    @adapter = Llm::Anthropic.new
    @api_response = {
      "content" => [ { "text" => '{"results": {"rights-002": {"has_risk": true, "confidence": "high", "reasoning": "test"}}}' } ],
      "model" => "claude-sonnet-4-20250514",
      "role" => "assistant"
    }
  end

  test "raises error when API key is not configured" do
    original_key = ENV["ANTHROPIC_API_KEY"]
    ENV.delete("ANTHROPIC_API_KEY")
    error = assert_raises(RuntimeError) { @adapter.analyze(system: "test", prompt: "test") }
    assert_match(/ANTHROPIC_API_KEY not configured/, error.message)
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_key
  end

  test "sends correct request to Anthropic API" do
    original_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"

    stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
      .with(
        headers: { "x-api-key" => "test-key", "anthropic-version" => "2023-06-01" }
      )
      .to_return(status: 200, body: @api_response.to_json, headers: { "Content-Type" => "application/json" })

    result = @adapter.analyze(system: "system prompt", prompt: "user prompt")

    assert_requested stub
    assert_equal true, result["results"]["rights-002"]["has_risk"]
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_key
  end

  test "uses LLM_MODEL override when set" do
    original_key = ENV["ANTHROPIC_API_KEY"]
    original_model = ENV["LLM_MODEL"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    ENV["LLM_MODEL"] = "claude-opus-4-20250514"

    stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
      .with { |req| JSON.parse(req.body)["model"] == "claude-opus-4-20250514" }
      .to_return(status: 200, body: @api_response.to_json, headers: { "Content-Type" => "application/json" })

    @adapter.analyze(system: "test", prompt: "test")
    assert_requested stub
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_key
    ENV["LLM_MODEL"] = original_model
  end

  test "raises error on API failure" do
    original_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"

    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 500, body: '{"error": "server error"}', headers: { "Content-Type" => "application/json" })

    assert_raises(RuntimeError) { @adapter.analyze(system: "test", prompt: "test") }
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_key
  end

  test "handles markdown-wrapped JSON response" do
    original_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"

    wrapped_response = {
      "content" => [ { "text" => "```json\n{\"results\": {}}\n```" } ],
      "role" => "assistant"
    }
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: wrapped_response.to_json, headers: { "Content-Type" => "application/json" })

    result = @adapter.analyze(system: "test", prompt: "test")
    assert_equal({}, result["results"])
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_key
  end
end
