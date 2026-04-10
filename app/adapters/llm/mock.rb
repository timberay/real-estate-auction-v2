module Llm
  class Mock < Base
    FIXTURE_PATH = Rails.root.join("test/fixtures/files/ai_inspection_response.json")

    def analyze(system:, prompt:)
      JSON.parse(File.read(FIXTURE_PATH))
    end

    def provider_name
      "mock"
    end

    def model_id
      "mock"
    end
  end
end
