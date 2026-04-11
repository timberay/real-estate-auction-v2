module Llm
  class Base
    TIMEOUT_SECONDS = 120

    PDF_UNSUPPORTED_ERROR = "이 모델은 PDF 분석을 지원하지 않습니다. Anthropic Claude 또는 Gemini를 사용해주세요."

    def self.for
      return Llm::Mock.new if ENV["USE_MOCK"] == "true"

      provider = ENV.fetch("LLM_PROVIDER", "anthropic")
      case provider
      when "anthropic"   then Llm::Anthropic.new
      when "openai"      then Llm::OpenAi.new
      when "gemini"      then Llm::Gemini.new
      when "ollama"      then Llm::Ollama.new
      when "openrouter"  then Llm::OpenRouter.new
      else raise ArgumentError, "Unknown LLM provider: #{provider}"
      end
    end

    def analyze(system:, prompt:, documents: [])
      if documents.any? && !supports_documents?
        raise PDF_UNSUPPORTED_ERROR
      end
      raise NotImplementedError, "#{self.class}#analyze must be implemented"
    end

    def supports_documents?
      false
    end

    def provider_name
      raise NotImplementedError, "#{self.class}#provider_name must be implemented"
    end

    def model_id
      raise NotImplementedError, "#{self.class}#model_id must be implemented"
    end

    private

    def api_key(provider_name, env_key)
      Rails.application.credentials.dig(provider_name.to_sym, :api_key) || ENV[env_key]
    end

    def model_name(default)
      ENV.fetch("LLM_MODEL", default)
    end

    def connection(base_url)
      Faraday.new(url: base_url) do |f|
        f.options.timeout = TIMEOUT_SECONDS
        f.options.open_timeout = 10
        f.request :json
        f.response :json
      end
    end

    def sanitize_and_parse_json(raw)
      cleaned = raw.strip
        .gsub(/\A```(?:json)?\s*\n?/, "")
        .gsub(/\n?```\s*\z/, "")
      JSON.parse(cleaned)
    end

    def handle_response(response)
      unless response.success?
        raise "LLM API error (#{response.status}): #{response.body}"
      end
    end

    def encode_pdf_base64(blob_or_path)
      if blob_or_path.respond_to?(:download)
        Base64.strict_encode64(blob_or_path.download)
      else
        Base64.strict_encode64(File.read(blob_or_path))
      end
    end
  end
end
