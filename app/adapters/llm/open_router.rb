module Llm
  class OpenRouter < Base
    DEFAULT_BASE_URL = "https://openrouter.ai"
    DEFAULT_MODEL = "anthropic/claude-sonnet-4-20250514"
    DEFAULT_MAX_TOKENS = 4096

    def provider_name
      "openrouter"
    end

    def model_id
      model_name(DEFAULT_MODEL, env_key: "OPENROUTER_MODEL")
    end

    def analyze(system:, prompt:)
      key = api_key("openrouter", "OPENROUTER_API_KEY")
      raise "OPENROUTER_API_KEY not configured. Set USE_MOCK=true for development." unless key

      conn = connection(base_url)
      response = conn.post("/v1/chat/completions") do |req|
        req.headers["Authorization"] = "Bearer #{key}"
        req.body = {
          model: model_id,
          max_tokens: max_tokens,
          messages: [
            { role: "system", content: system },
            { role: "user", content: prompt }
          ]
        }
      end
      handle_response(response)
      detect_truncation(response.body)
      sanitize_and_parse_json(response.body["choices"][0]["message"]["content"])
    end

    private

    def base_url
      ENV.fetch("OPENROUTER_BASE_URL", DEFAULT_BASE_URL)
    end

    def max_tokens
      ENV.fetch("OPENROUTER_MAX_TOKENS", DEFAULT_MAX_TOKENS).to_i
    end

    def detect_truncation(body)
      return unless body.is_a?(Hash) && body.dig("choices", 0, "finish_reason") == "length"
      raise_truncated!(env_var: "OPENROUTER_MAX_TOKENS")
    end
  end
end
