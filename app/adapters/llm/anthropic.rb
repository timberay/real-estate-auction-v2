module Llm
  class Anthropic < Base
    BASE_URL = "https://api.anthropic.com"
    DEFAULT_MODEL = "claude-sonnet-4-20250514"

    def analyze(system:, prompt:)
      key = api_key("anthropic", "ANTHROPIC_API_KEY")
      raise "ANTHROPIC_API_KEY not configured. Set USE_MOCK=true for development." unless key

      conn = connection(BASE_URL)
      response = conn.post("/v1/messages") do |req|
        req.headers["x-api-key"] = key
        req.headers["anthropic-version"] = "2023-06-01"
        req.body = {
          model: model_name(DEFAULT_MODEL),
          max_tokens: 4096,
          system: system,
          messages: [ { role: "user", content: prompt } ]
        }
      end
      handle_response(response)
      sanitize_and_parse_json(response.body["content"][0]["text"])
    end
  end
end
