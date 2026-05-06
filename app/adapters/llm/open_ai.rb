module Llm
  class OpenAi < Base
    DEFAULT_BASE_URL = "https://api.openai.com"
    DEFAULT_MODEL = "gpt-4o-mini"
    DEFAULT_MAX_TOKENS = 4096

    def provider_name
      "openai"
    end

    def model_id
      model_name(DEFAULT_MODEL, env_key: "OPENAI_MODEL")
    end

    def analyze(system:, prompt:)
      key = api_key("openai", "OPENAI_API_KEY")
      raise "OPENAI_API_KEY not configured. Set USE_MOCK=true for development." unless key

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
      sanitize_and_parse_json(response.body["choices"][0]["message"]["content"])
    end

    private

    def base_url
      ENV.fetch("OPENAI_BASE_URL", DEFAULT_BASE_URL)
    end

    def max_tokens
      ENV.fetch("OPENAI_MAX_TOKENS", DEFAULT_MAX_TOKENS).to_i
    end
  end
end
