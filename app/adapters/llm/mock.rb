module Llm
  class Mock < Base
    FIXTURE_PATH = Rails.root.join("test/fixtures/files/ai_inspection_response.json")

    attr_writer :override_response

    def analyze(system:, prompt:, documents: [])
      return @override_response if @override_response

      JSON.parse(File.read(FIXTURE_PATH))
    end

    def supports_documents?
      true
    end

    def provider_name
      "mock"
    end

    def model_id
      "mock"
    end
  end
end
