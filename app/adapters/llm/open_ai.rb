module Llm
  class OpenAi < Base
    BASE_URL = "https://api.openai.com"
    DEFAULT_MODEL = "gpt-4o-mini"

    def analyze(system:, prompt:)
      raise NotImplementedError, "#{self.class}#analyze not yet implemented"
    end
  end
end
