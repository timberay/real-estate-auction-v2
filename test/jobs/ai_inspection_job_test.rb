require "test_helper"

class AiInspectionJobTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    ENV["USE_MOCK"] = "true"
  end

  teardown do
    ENV.delete("USE_MOCK")
  end

  test "calls AiInspectionRunner with property and no user" do
    original_method = Inspection::InspectionResultMapper.method(:call)
    Inspection::InspectionResultMapper.define_singleton_method(:call) { |**| nil }

    AiInspectionJob.perform_now(@property)

    log = @property.llm_analysis_logs.last
    assert_not_nil log
    assert log.completed?
    assert_nil log.user
  ensure
    Inspection::InspectionResultMapper.define_singleton_method(:call, original_method)
  end

  test "does not raise when AiInspectionRunner fails" do
    original_for = Llm::Base.method(:for)

    error_adapter = Object.new
    error_adapter.define_singleton_method(:provider_name) { "mock" }
    error_adapter.define_singleton_method(:model_id) { "mock" }
    error_adapter.define_singleton_method(:analyze) { |system:, prompt:| raise "LLM API error" }

    Llm::Base.define_singleton_method(:for) { error_adapter }

    assert_nothing_raised do
      AiInspectionJob.perform_now(@property)
    end

    log = @property.llm_analysis_logs.last
    assert log.failed?
  ensure
    Llm::Base.define_singleton_method(:for, original_for)
  end
end
