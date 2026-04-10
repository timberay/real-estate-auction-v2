module Llm
  class OpenRouter < Base
    BASE_URL = "https://openrouter.ai"
    DEFAULT_MODEL = "anthropic/claude-sonnet-4-20250514"

    def analyze(system:, prompt:)
      key = api_key("openrouter", "OPENROUTER_API_KEY")
      raise "OPENROUTER_API_KEY not configured. Set USE_MOCK=true for development." unless key

      conn = connection(BASE_URL)
      response = conn.post("/v1/chat/completions") do |req|
        req.headers["Authorization"] = "Bearer #{key}"
        req.body = {
          model: model_name(DEFAULT_MODEL),
          max_tokens: 4096,
          messages: [
            { role: "system", content: system },
            { role: "user", content: prompt }
          ]
        }
      end
      handle_response(response)
      sanitize_and_parse_json(response.body["choices"][0]["message"]["content"])
    end
  end
end
