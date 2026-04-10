require "test_helper"

class AiInspectionRunnerTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    @user = users(:guest)
    ENV["USE_MOCK"] = "true"
  end

  teardown do
    ENV.delete("USE_MOCK")
  end

  test "creates inspection results for all rights_analysis items" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)

    items = InspectionItem.where(tab: :rights_analysis)
    items.each do |item|
      result = InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
      assert_not_nil result, "Missing result for #{item.code}"
    end
  end

  test "sets source_type to ai for high confidence results" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)

    result = find_result("rights-002")
    assert result.ai?
    assert result.has_risk
    assert_equal "AI 분석", result.evidence["source_label"]
  end

  test "preserves manual answers" do
    AiInspectionRunner.call(property: @property, user: @user)

    result = find_result("manual-001")
    assert result.manual?
  end

  test "is idempotent — running twice does not create duplicates" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)
    count_after_first = InspectionResult.where(property: @property, user: @user).count

    AiInspectionRunner.call(property: @property, user: @user)
    count_after_second = InspectionResult.where(property: @property, user: @user).count

    assert_equal count_after_first, count_after_second
  end

  test "creates LlmAnalysisLog with pending status before LLM call" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)

    log = @property.llm_analysis_logs.last
    assert_not_nil log
    assert log.completed?
    assert_not_nil log.system_prompt
    assert_not_nil log.user_prompt
    assert_equal "mock", log.provider
    assert_equal "mock", log.model
  end

  test "stores response_json on successful LLM call" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)

    log = @property.llm_analysis_logs.last
    assert log.completed?
    assert_not_nil log.response_json
    assert log.response_json.key?("results")
    assert_not_nil log.executed_at
  end

  test "stores user_id when user is provided" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)

    log = @property.llm_analysis_logs.last
    assert_equal @user, log.user
  end

  test "allows nil user for system-triggered runs" do
    original_method = Inspection::InspectionResultMapper.method(:call)
    Inspection::InspectionResultMapper.define_singleton_method(:call) { |**| nil }

    AiInspectionRunner.call(property: @property, user: nil)

    log = @property.llm_analysis_logs.last
    assert_nil log.user
    assert log.completed?
  ensure
    Inspection::InspectionResultMapper.define_singleton_method(:call, original_method)
  end

  test "marks log as failed when LLM raises error" do
    failing_adapter = Llm::Mock.new
    failing_adapter.define_singleton_method(:analyze) { |**| raise "LLM API error (500): Internal server error" }

    original_for = Llm::Base.method(:for)
    Llm::Base.define_singleton_method(:for) { failing_adapter }

    assert_raises(RuntimeError) do
      AiInspectionRunner.call(property: @property, user: @user)
    end

    log = @property.llm_analysis_logs.last
    assert log.failed?
    assert_includes log.error_message, "LLM API error"
    assert_nil log.response_json
  ensure
    Llm::Base.define_singleton_method(:for, original_for)
  end

  test "creates new log each run (history preserved)" do
    @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

    AiInspectionRunner.call(property: @property, user: @user)
    first_count = @property.llm_analysis_logs.count

    AiInspectionRunner.call(property: @property, user: @user)
    assert_equal first_count + 1, @property.llm_analysis_logs.count
  end

  private

  def find_result(code)
    item = InspectionItem.find_by(code: code)
    InspectionResult.find_by(property: @property, inspection_item: item, user: @user)
  end
end
