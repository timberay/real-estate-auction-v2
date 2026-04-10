module Llm
  class Gemini < Base
    BASE_URL = "https://generativelanguage.googleapis.com"
    DEFAULT_MODEL = "gemini-2.5-flash"

    def provider_name
      "gemini"
    end

    def model_id
      model_name(DEFAULT_MODEL)
    end

    def analyze(system:, prompt:)
      key = api_key("gemini", "GEMINI_API_KEY")
      raise "GEMINI_API_KEY not configured. Set USE_MOCK=true for development." unless key

      model = model_name(DEFAULT_MODEL)
      conn = connection(BASE_URL)
      response = conn.post("/v1beta/models/#{model}:generateContent") do |req|
        req.params["key"] = key
        req.body = {
          system_instruction: { parts: [ { text: system } ] },
          contents: [ { parts: [ { text: prompt } ] } ]
        }
      end
      handle_response(response)
      text = response.body["candidates"][0]["content"]["parts"][0]["text"]
      sanitize_and_parse_json(text)
    end
  end
end
