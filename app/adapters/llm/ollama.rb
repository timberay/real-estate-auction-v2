module Llm
  class Ollama < Base
    DEFAULT_MODEL = "llama3.1"

    def analyze(system:, prompt:)
      raise NotImplementedError, "#{self.class}#analyze not yet implemented"
    end

    private

    def base_url
      ENV.fetch("OLLAMA_BASE_URL", "http://localhost:11434")
    end
  end
end
