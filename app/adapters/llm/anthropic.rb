module Llm
  class Anthropic < Base
    DEFAULT_BASE_URL = "https://api.anthropic.com"
    DEFAULT_MODEL = "claude-sonnet-4-20250514"
    DEFAULT_MAX_TOKENS = 16384
    DEFAULT_API_VERSION = "2023-06-01"

    def provider_name
      "anthropic"
    end

    def model_id
      model_name(DEFAULT_MODEL, env_key: "ANTHROPIC_MODEL")
    end

    def supports_documents?
      true
    end

    def analyze(system:, prompt:, documents: [])
      key = api_key("anthropic", "ANTHROPIC_API_KEY")
      raise "ANTHROPIC_API_KEY not configured. Set USE_MOCK=true for development." unless key

      encoded_docs = documents.map { |doc| encode_pdf_base64(doc) }
      user_content = build_user_content(prompt, encoded_docs)

      conn = connection(base_url)
      response = conn.post("/v1/messages") do |req|
        req.headers["x-api-key"] = key
        req.headers["anthropic-version"] = api_version
        req.body = {
          model: model_id,
          max_tokens: max_tokens,
          system: system,
          messages: [ { role: "user", content: user_content } ]
        }
      end
      handle_response(response)
      detect_truncation(response.body)
      sanitize_and_parse_json(response.body["content"][0]["text"])
    end

    private

    def base_url
      ENV.fetch("ANTHROPIC_BASE_URL", DEFAULT_BASE_URL)
    end

    def max_tokens
      ENV.fetch("ANTHROPIC_MAX_TOKENS", DEFAULT_MAX_TOKENS).to_i
    end

    def api_version
      ENV.fetch("ANTHROPIC_API_VERSION", DEFAULT_API_VERSION)
    end

    # Fail fast when Anthropic stops generation because it ran out of token
    # budget. Without this, downstream `sanitize_and_parse_json` would crash on
    # incomplete JSON with a confusing parser error instead of pointing at the
    # real cause.
    def detect_truncation(body)
      return unless body.is_a?(Hash) && body["stop_reason"] == "max_tokens"

      raise_truncated!(env_var: "ANTHROPIC_MAX_TOKENS")
    end

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
