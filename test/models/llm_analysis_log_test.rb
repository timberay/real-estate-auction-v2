require "test_helper"

class LlmAnalysisLogTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    @user = users(:guest)
  end

  test "valid with required attributes" do
    log = LlmAnalysisLog.new(
      property: @property,
      system_prompt: "You are an expert.",
      user_prompt: "Analyze this property."
    )
    assert log.valid?
  end

  test "valid without user (system-triggered)" do
    log = LlmAnalysisLog.new(
      property: @property,
      user: nil,
      system_prompt: "You are an expert.",
      user_prompt: "Analyze this property."
    )
    assert log.valid?
  end

  test "invalid without property" do
    log = LlmAnalysisLog.new(
      system_prompt: "You are an expert.",
      user_prompt: "Analyze this property."
    )
    assert_not log.valid?
    assert_includes log.errors[:property], "이(가) 필요합니다"
  end

  test "invalid without system_prompt" do
    log = LlmAnalysisLog.new(
      property: @property,
      system_prompt: nil,
      user_prompt: "Analyze this property."
    )
    assert_not log.valid?
    assert_includes log.errors[:system_prompt], "을(를) 입력해 주세요"
  end

  test "invalid without user_prompt" do
    log = LlmAnalysisLog.new(
      property: @property,
      system_prompt: "You are an expert.",
      user_prompt: nil
    )
    assert_not log.valid?
    assert_includes log.errors[:user_prompt], "을(를) 입력해 주세요"
  end

  test "status enum values" do
    log = LlmAnalysisLog.new(
      property: @property,
      system_prompt: "test",
      user_prompt: "test"
    )

    log.status = :pending
    assert log.pending?

    log.status = :completed
    assert log.completed?

    log.status = :failed
    assert log.failed?
  end

  test "default status is pending" do
    log = LlmAnalysisLog.new(
      property: @property,
      system_prompt: "test",
      user_prompt: "test"
    )
    assert log.pending?
  end

  test "PII columns are encrypted at rest" do
    log = LlmAnalysisLog.create!(
      property: @property,
      user: users(:guest),
      system_prompt: "secret-system-text",
      user_prompt: "secret-user-text",
      response_json: { "secret" => "value" },
      status: :completed,
      executed_at: Time.current,
      provider: "test",
      model: "test"
    )
    raw = ActiveRecord::Base.connection.execute(
      "SELECT system_prompt, user_prompt, response_json FROM llm_analysis_logs WHERE id = #{log.id}"
    ).first
    refute_includes raw["system_prompt"], "secret-system-text"
    refute_includes raw["user_prompt"], "secret-user-text"
    refute_includes raw["response_json"], "value"
    # Model still decrypts on read:
    log.reload
    assert_equal "secret-system-text", log.system_prompt
    assert_equal({ "secret" => "value" }, log.response_json)
  end

  test "latest_for scope returns most recent completed log" do
    older = LlmAnalysisLog.create!(
      property: @property, system_prompt: "s", user_prompt: "u",
      status: :completed, executed_at: 2.hours.ago
    )
    newer = LlmAnalysisLog.create!(
      property: @property, system_prompt: "s", user_prompt: "u",
      status: :completed, executed_at: 1.hour.ago
    )
    failed = LlmAnalysisLog.create!(
      property: @property, system_prompt: "s", user_prompt: "u",
      status: :failed
    )

    result = LlmAnalysisLog.latest_for(@property)
    assert_equal newer, result
  end
end
