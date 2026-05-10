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

  test "DEFAULT_MAX_TOKENS is 16384 to fit 89-item inspection + rights_analysis output" do
    assert_equal 16384, Llm::Anthropic::DEFAULT_MAX_TOKENS
  end

  test "sends max_tokens=16384 in request body by default" do
    original_key = ENV["ANTHROPIC_API_KEY"]
    original_max = ENV["ANTHROPIC_MAX_TOKENS"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    ENV.delete("ANTHROPIC_MAX_TOKENS")

    stub = stub_request(:post, "https://api.anthropic.com/v1/messages")
      .with { |req| JSON.parse(req.body)["max_tokens"] == 16384 }
      .to_return(status: 200, body: @api_response.to_json, headers: { "Content-Type" => "application/json" })

    @adapter.analyze(system: "test", prompt: "test")
    assert_requested stub
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_key
    ENV["ANTHROPIC_MAX_TOKENS"] = original_max
  end

  test "raises ResponseTruncated when stop_reason is max_tokens" do
    original_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"

    truncated_response = {
      "content" => [ { "text" => '{"partial":' } ],
      "stop_reason" => "max_tokens",
      "role" => "assistant"
    }
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: truncated_response.to_json, headers: { "Content-Type" => "application/json" })

    error = assert_raises(Llm::Errors::ResponseTruncated) do
      @adapter.analyze(system: "test", prompt: "test")
    end
    assert_match(/max_tokens/, error.message)
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_key
  end

  test "parses normally when stop_reason is end_turn" do
    original_key = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"

    normal_response = @api_response.merge("stop_reason" => "end_turn")
    stub_request(:post, "https://api.anthropic.com/v1/messages")
      .to_return(status: 200, body: normal_response.to_json, headers: { "Content-Type" => "application/json" })

    result = @adapter.analyze(system: "test", prompt: "test")
    assert_equal true, result["results"]["rights-002"]["has_risk"]
  ensure
    ENV["ANTHROPIC_API_KEY"] = original_key
  end
end
