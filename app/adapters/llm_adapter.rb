class LlmAdapter
  def self.for
    if ENV["USE_MOCK"] == "true"
      MockLlmAdapter.new
    else
      AnthropicLlmAdapter.new
    end
  end

  def analyze(system:, prompt:)
    raise NotImplementedError, "#{self.class}#analyze must be implemented"
  end

  private

  # LLMs often wrap JSON in markdown code blocks (```json ... ```).
  # This strips that wrapper before parsing.
  def sanitize_and_parse_json(raw)
    cleaned = raw.strip
      .gsub(/\A```(?:json)?\s*\n?/, "")
      .gsub(/\n?```\s*\z/, "")
    JSON.parse(cleaned)
  end
end
