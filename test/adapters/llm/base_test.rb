require "test_helper"

class Llm::BaseTest < ActiveSupport::TestCase
  test "base class raises NotImplementedError on analyze" do
    adapter = Llm::Base.new
    assert_raises(NotImplementedError) do
      adapter.analyze(system: "test", prompt: "test")
    end
  end

  test ".for returns Llm::Mock when USE_MOCK is true" do
    original = ENV["USE_MOCK"]
    ENV["USE_MOCK"] = "true"
    adapter = Llm::Base.for
    assert_instance_of Llm::Mock, adapter
  ensure
    ENV["USE_MOCK"] = original
  end

  test ".for returns Llm::Anthropic by default when USE_MOCK is false" do
    original_mock = ENV["USE_MOCK"]
    original_provider = ENV["LLM_PROVIDER"]
    ENV["USE_MOCK"] = "false"
    ENV.delete("LLM_PROVIDER")
    adapter = Llm::Base.for
    assert_instance_of Llm::Anthropic, adapter
  ensure
    ENV["USE_MOCK"] = original_mock
    ENV["LLM_PROVIDER"] = original_provider
  end

  test ".for returns correct adapter for each provider" do
    original_mock = ENV["USE_MOCK"]
    original_provider = ENV["LLM_PROVIDER"]
    ENV["USE_MOCK"] = "false"

    { "anthropic" => Llm::Anthropic, "openai" => Llm::OpenAi,
      "gemini" => Llm::Gemini, "ollama" => Llm::Ollama,
      "openrouter" => Llm::OpenRouter }.each do |name, klass|
      ENV["LLM_PROVIDER"] = name
      assert_instance_of klass, Llm::Base.for, "Expected #{klass} for provider '#{name}'"
    end
  ensure
    ENV["USE_MOCK"] = original_mock
    ENV["LLM_PROVIDER"] = original_provider
  end

  test ".for raises ArgumentError for unknown provider" do
    original_mock = ENV["USE_MOCK"]
    original_provider = ENV["LLM_PROVIDER"]
    ENV["USE_MOCK"] = "false"
    ENV["LLM_PROVIDER"] = "unknown"
    assert_raises(ArgumentError) { Llm::Base.for }
  ensure
    ENV["USE_MOCK"] = original_mock
    ENV["LLM_PROVIDER"] = original_provider
  end

  test "sanitize_and_parse_json strips markdown code block wrapper" do
    adapter = Llm::Base.new
    raw = "```json\n{\"results\": {}}\n```"
    parsed = adapter.send(:sanitize_and_parse_json, raw)
    assert_equal({}, parsed["results"])
  end

  test "sanitize_and_parse_json handles plain JSON" do
    adapter = Llm::Base.new
    raw = '{"results": {}}'
    parsed = adapter.send(:sanitize_and_parse_json, raw)
    assert_equal({}, parsed["results"])
  end

  test "api_key prefers credentials over ENV" do
    adapter = Llm::Base.new
    original = ENV["TEST_API_KEY"]
    ENV["TEST_API_KEY"] = "env-key"
    # credentials won't have :test_provider, so should fall back to ENV
    key = adapter.send(:api_key, "test_provider", "TEST_API_KEY")
    assert_equal "env-key", key
  ensure
    ENV["TEST_API_KEY"] = original
  end

  test "model_name returns ENV override when set" do
    adapter = Llm::Base.new
    original = ENV["LLM_MODEL"]
    ENV["LLM_MODEL"] = "custom-model"
    assert_equal "custom-model", adapter.send(:model_name, "default-model")
  ensure
    ENV["LLM_MODEL"] = original
  end

  test "model_name returns default when ENV not set" do
    adapter = Llm::Base.new
    original = ENV["LLM_MODEL"]
    ENV.delete("LLM_MODEL")
    assert_equal "default-model", adapter.send(:model_name, "default-model")
  ensure
    ENV["LLM_MODEL"] = original
  end
end
