module Llm
  class Ollama < Base
    DEFAULT_BASE_URL = "http://localhost:11434"
    DEFAULT_MODEL = "llama3.1"

    def provider_name
      "ollama"
    end

    def model_id
      model_name(DEFAULT_MODEL, env_key: "OLLAMA_MODEL")
    end

    def analyze(system:, prompt:, documents: [])
      raise Llm::Base::PDF_UNSUPPORTED_ERROR if documents.any?

      conn = connection(base_url)
      response = conn.post("/api/chat") do |req|
        req.body = {
          model: model_id,
          stream: false,
          messages: [
            { role: "system", content: system },
            { role: "user", content: prompt }
          ]
        }
      end
      handle_response(response)
      sanitize_and_parse_json(response.body["message"]["content"])
    end

    private

    def base_url
      ENV.fetch("OLLAMA_BASE_URL", DEFAULT_BASE_URL)
    end
  end
end
