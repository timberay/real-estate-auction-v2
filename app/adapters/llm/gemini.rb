module Llm
  class Gemini < Base
    BASE_URL = "https://generativelanguage.googleapis.com"
    DEFAULT_MODEL = "gemini-2.0-flash"

    def analyze(system:, prompt:)
      raise NotImplementedError, "#{self.class}#analyze not yet implemented"
    end
  end
end
