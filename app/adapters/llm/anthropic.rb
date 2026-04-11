module Llm
  class Anthropic < Base
    BASE_URL = "https://api.anthropic.com"
    DEFAULT_MODEL = "claude-sonnet-4-20250514"

    def provider_name
      "anthropic"
    end

    def model_id
      model_name(DEFAULT_MODEL)
    end

    def supports_documents?
      true
    end

    def analyze(system:, prompt:, documents: [])
      key = api_key("anthropic", "ANTHROPIC_API_KEY")
      raise "ANTHROPIC_API_KEY not configured. Set USE_MOCK=true for development." unless key

      encoded_docs = documents.map { |doc| encode_pdf_base64(doc) }
      user_content = build_user_content(prompt, encoded_docs)

      conn = connection(BASE_URL)
      response = conn.post("/v1/messages") do |req|
        req.headers["x-api-key"] = key
        req.headers["anthropic-version"] = "2023-06-01"
        req.body = {
          model: model_name(DEFAULT_MODEL),
          max_tokens: 8192,
          system: system,
          messages: [ { role: "user", content: user_content } ]
        }
      end
      handle_response(response)
      sanitize_and_parse_json(response.body["content"][0]["text"])
    end

    private

    def build_user_content(prompt, encoded_pdfs)
      content = []

      encoded_pdfs.each do |pdf_base64|
        content << {
          type: "document",
          source: {
            type: "base64",
            media_type: "application/pdf",
            data: pdf_base64
          }
        }
      end

      content << { type: "text", text: prompt }
      content
    end
  end
end
