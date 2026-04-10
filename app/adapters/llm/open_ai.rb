module Llm
  class OpenAi < Base
    BASE_URL = "https://api.openai.com"
    DEFAULT_MODEL = "gpt-4o-mini"

    def provider_name
      "openai"
    end

    def model_id
      model_name(DEFAULT_MODEL)
    end

    def analyze(system:, prompt:)
      key = api_key("openai", "OPENAI_API_KEY")
      raise "OPENAI_API_KEY not configured. Set USE_MOCK=true for development." unless key

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
