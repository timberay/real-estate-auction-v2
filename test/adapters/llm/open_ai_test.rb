require "test_helper"

class Llm::OpenAiTest < ActiveSupport::TestCase
  setup do
    @adapter = Llm::OpenAi.new
    @api_response = {
      "choices" => [ { "message" => { "content" => '{"results": {"rights-002": {"has_risk": true, "confidence": "high", "reasoning": "test"}}}' } } ]
    }
  end

  test "raises error when API key is not configured" do
    original = ENV["OPENAI_API_KEY"]
    ENV.delete("OPENAI_API_KEY")
    error = assert_raises(RuntimeError) { @adapter.analyze(system: "test", prompt: "test") }
    assert_match(/OPENAI_API_KEY not configured/, error.message)
  ensure
    ENV["OPENAI_API_KEY"] = original
  end

  test "sends correct request to OpenAI API" do
    original = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"

    stub = stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .with(headers: { "Authorization" => "Bearer test-key" })
      .to_return(status: 200, body: @api_response.to_json, headers: { "Content-Type" => "application/json" })

    result = @adapter.analyze(system: "system", prompt: "user")
    assert_requested stub
    assert_equal true, result["results"]["rights-002"]["has_risk"]
  ensure
    ENV["OPENAI_API_KEY"] = original
  end

  test "raises error on API failure" do
    original = ENV["OPENAI_API_KEY"]
    ENV["OPENAI_API_KEY"] = "test-key"

    stub_request(:post, "https://api.openai.com/v1/chat/completions")
      .to_return(status: 429, body: '{"error": "rate limited"}', headers: { "Content-Type" => "application/json" })

    assert_raises(RuntimeError) { @adapter.analyze(system: "test", prompt: "test") }
  ensure
    ENV["OPENAI_API_KEY"] = original
  end
end
