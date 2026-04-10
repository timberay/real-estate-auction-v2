class AnthropicLlmAdapter < LlmAdapter
  TIMEOUT_SECONDS = 30

  # Future implementation will:
  # 1. Use response_format: { type: "json" } to force pure JSON from API
  # 2. Use sanitize_and_parse_json as fallback for markdown-wrapped responses
  # 3. Set HTTP timeout to TIMEOUT_SECONDS — on timeout, raises error
  #    which PropertyInspectionService catches to trigger InspectionRunner fallback
  def analyze(system:, prompt:)
    raise NotImplementedError,
      "AnthropicLlmAdapter requires ANTHROPIC_API_KEY. " \
      "Set USE_MOCK=true for development, or configure API key for production."
  end
end
