require "test_helper"

class Llm::GeminiTest < ActiveSupport::TestCase
  setup do
    @adapter = Llm::Gemini.new
    @api_response = {
      "candidates" => [ { "content" => { "parts" => [ { "text" => '{"results": {"rights-002": {"has_risk": true, "confidence": "high", "reasoning": "test"}}}' } ] } } ]
    }
  end

  test "raises error when API key is not configured" do
    original = ENV["GEMINI_API_KEY"]
    ENV.delete("GEMINI_API_KEY")
    error = assert_raises(RuntimeError) { @adapter.analyze(system: "test", prompt: "test") }
    assert_match(/GEMINI_API_KEY not configured/, error.message)
  ensure
    ENV["GEMINI_API_KEY"] = original
  end

  test "sends correct request to Gemini API" do
    original = ENV["GEMINI_API_KEY"]
    ENV["GEMINI_API_KEY"] = "test-key"

    stub = stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")
      .with(headers: { "x-goog-api-key" => "test-key" })
      .to_return(status: 200, body: @api_response.to_json, headers: { "Content-Type" => "application/json" })

    result = @adapter.analyze(system: "system", prompt: "user")
    assert_requested stub
    assert_equal true, result["results"]["rights-002"]["has_risk"]
  ensure
    ENV["GEMINI_API_KEY"] = original
  end

  test "raises error on API failure" do
    original = ENV["GEMINI_API_KEY"]
    ENV["GEMINI_API_KEY"] = "test-key"

    stub_request(:post, "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent")
      .with(headers: { "x-goog-api-key" => "test-key" })
      .to_return(status: 400, body: '{"error": "bad request"}', headers: { "Content-Type" => "application/json" })

    assert_raises(RuntimeError) { @adapter.analyze(system: "test", prompt: "test") }
  ensure
    ENV["GEMINI_API_KEY"] = original
  end
end
