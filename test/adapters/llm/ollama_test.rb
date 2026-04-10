require "test_helper"

class Llm::OllamaTest < ActiveSupport::TestCase
  setup do
    @adapter = Llm::Ollama.new
    @api_response = {
      "message" => { "content" => '{"results": {"rights-002": {"has_risk": true, "confidence": "high", "reasoning": "test"}}}' }
    }
  end

  test "sends correct request to Ollama API" do
    stub = stub_request(:post, "http://localhost:11434/api/chat")
      .to_return(status: 200, body: @api_response.to_json, headers: { "Content-Type" => "application/json" })

    result = @adapter.analyze(system: "system", prompt: "user")
    assert_requested stub
    assert_equal true, result["results"]["rights-002"]["has_risk"]
  end

  test "uses custom OLLAMA_BASE_URL when set" do
    original = ENV["OLLAMA_BASE_URL"]
    ENV["OLLAMA_BASE_URL"] = "http://gpu-server:11434"

    stub = stub_request(:post, "http://gpu-server:11434/api/chat")
      .to_return(status: 200, body: @api_response.to_json, headers: { "Content-Type" => "application/json" })

    @adapter.analyze(system: "system", prompt: "user")
    assert_requested stub
  ensure
    ENV["OLLAMA_BASE_URL"] = original
  end

  test "sends stream false to prevent streaming" do
    stub = stub_request(:post, "http://localhost:11434/api/chat")
      .with { |req| JSON.parse(req.body)["stream"] == false }
      .to_return(status: 200, body: @api_response.to_json, headers: { "Content-Type" => "application/json" })

    @adapter.analyze(system: "system", prompt: "user")
    assert_requested stub
  end

  test "raises error on API failure" do
    stub_request(:post, "http://localhost:11434/api/chat")
      .to_return(status: 500, body: '{"error": "model not found"}', headers: { "Content-Type" => "application/json" })

    assert_raises(RuntimeError) { @adapter.analyze(system: "test", prompt: "test") }
  end
end
