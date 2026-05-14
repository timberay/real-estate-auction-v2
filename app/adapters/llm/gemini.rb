module Llm
  class Gemini < Base
    DEFAULT_BASE_URL = "https://generativelanguage.googleapis.com"
    DEFAULT_MODEL = "gemini-2.5-flash"

    def provider_name
      "gemini"
    end

    def model_id
      model_name(DEFAULT_MODEL, env_key: "GEMINI_MODEL")
    end

    def supports_documents?
      true
    end

    def analyze(system:, prompt:, documents: [])
      key = api_key("gemini", "GEMINI_API_KEY")
      raise "GEMINI_API_KEY not configured. Set USE_MOCK=true for development." unless key

      encoded_docs = documents.map { |doc| encode_pdf_base64(doc) }
      content_parts = build_content_parts(prompt, encoded_docs)

      model = model_id
      conn = connection(base_url)
      response = conn.post("/v1beta/models/#{model}:generateContent") do |req|
        req.headers["x-goog-api-key"] = key
        req.body = {
          system_instruction: { parts: [ { text: system } ] },
          contents: [ { parts: content_parts } ],
          generation_config: {
            response_mime_type: "application/json"
          }
        }
      end
      handle_response(response)
      detect_truncation(response.body)
      text = response.body["candidates"][0]["content"]["parts"][0]["text"]
      sanitize_and_parse_json(text)
    end

    private

    def base_url
      ENV.fetch("GEMINI_BASE_URL", DEFAULT_BASE_URL)
    end

    def detect_truncation(body)
      return unless body.is_a?(Hash) && body.dig("candidates", 0, "finishReason") == "MAX_TOKENS"
      raise_truncated!(env_var: "GEMINI_MAX_OUTPUT_TOKENS")
    end

    def build_content_parts(prompt, encoded_pdfs)
      parts = []

      encoded_pdfs.each do |pdf_base64|
        parts << {
          inline_data: {
            mime_type: "application/pdf",
            data: pdf_base64
          }
        }
      end

      parts << { text: prompt }
      parts
    end
  end
end
