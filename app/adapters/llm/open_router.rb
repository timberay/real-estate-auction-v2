module Llm
  class OpenRouter < Base
    BASE_URL = "https://openrouter.ai/api"
    DEFAULT_MODEL = "anthropic/claude-sonnet-4-20250514"

    def analyze(system:, prompt:)
      raise NotImplementedError, "#{self.class}#analyze not yet implemented"
    end
  end
end
