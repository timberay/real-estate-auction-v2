require "test_helper"

class AnalysesControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url # creates guest session
    @user = User.find(session[:user_id])
    @property = Property.create!(case_number: "2026타경CTL001")
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "GET new renders upload form" do
    get new_analysis_path
    assert_response :success
    assert_select "input[type=file]"
  end

  test "GET new with non-existent property_id redirects with alert" do
    get new_analysis_path(property_id: 99999)

    assert_redirected_to new_analysis_path
    assert_equal "해당 물건을 찾을 수 없습니다.", flash[:alert]
  end

  test "POST create with Turbo responds with form reset, toast, and indicator" do
    pdf = fixture_file_upload("test/fixtures/files/test.pdf", "application/pdf")

    post analyses_path, params: { property_id: @property.id, documents: [ pdf ] },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
    assert_includes response.body, 'action="replace"'
    assert_includes response.body, 'target="analysis_form"'
    assert_includes response.body, 'action="append"'
    assert_includes response.body, 'target="global_toasts"'
    assert_includes response.body, "분석이 시작되었습니다"
    assert_includes response.body, 'target="analysis_indicator"'
  end

  test "POST create without Turbo redirects with notice" do
    pdf = fixture_file_upload("test/fixtures/files/test.pdf", "application/pdf")

    post analyses_path, params: { property_id: @property.id, documents: [ pdf ] }

    assert_redirected_to new_analysis_path
    assert_equal "분석이 시작되었습니다.", flash[:notice]
  end

  test "POST create without documents shows alert" do
    post analyses_path, params: { property_id: @property.id }

    assert_redirected_to new_analysis_path
    assert flash[:alert].present?
  end

  test "POST create without property_id redirects with missing case number alert" do
    pdf = fixture_file_upload("test/fixtures/files/test.pdf", "application/pdf")

    post analyses_path, params: { documents: [ pdf ] }

    assert_redirected_to new_analysis_path
    assert_equal "사건번호를 먼저 입력해 주세요.", flash[:alert]
  end

  # Task 3: prompt action
  test "GET prompt returns JSON with prompt content" do
    get prompt_analyses_path

    assert_response :success
    assert_equal "application/json; charset=utf-8", response.content_type

    data = JSON.parse(response.body)
    assert data.key?("prompt")
    assert_includes data["prompt"], "부동산 경매 권리분석 전문가"
  end

  # Task 4: manual action
  test "POST manual with valid JSON processes and redirects to inspection tab" do
    # Property must already exist; service will find it by case_number from JSON
    property = Property.create!(case_number: "2024타경12345")
    json_file = fixture_file_upload("test/fixtures/files/ai_inspection_response.json", "application/json")

    post manual_analyses_path, params: { json_file: json_file }

    property.reload
    assert_redirected_to edit_property_inspections_tab_path(property, tab_key: "rights_analysis")
    assert_equal "분석 결과가 저장되었습니다.", flash[:notice]
  end

  test "POST manual without JSON file shows alert and stays on manual tab" do
    post manual_analyses_path, params: {}

    assert_redirected_to new_analysis_path(tab: "manual")
    assert_equal "JSON 파일을 업로드하거나 텍스트를 붙여넣어주세요.", flash[:alert]
  end

  test "POST manual with json_text param processes pasted JSON" do
    # Property must already exist; service will find it by case_number from JSON text
    Property.create!(case_number: "2024타경PASTE")
    json_text = { "metadata" => { "case_number" => "2024타경PASTE" }, "results" => {} }.to_json

    post manual_analyses_path, params: { json_text: json_text }

    property = Property.find_by(case_number: "2024타경PASTE")
    assert_not_nil property
  end

  test "POST manual with invalid JSON shows alert and stays on manual tab" do
    invalid_file = Rack::Test::UploadedFile.new(
      StringIO.new("this is not json"),
      "application/json",
      original_filename: "bad.json"
    )

    post manual_analyses_path, params: { json_file: invalid_file }

    assert_redirected_to new_analysis_path(tab: "manual")
    assert_equal "유효한 JSON 파일이 아닙니다. JSON만 포함된 파일인지 확인해주세요.", flash[:alert]
  end

  test "POST manual with JSON missing metadata key shows alert and stays on manual tab" do
    json_content = { "results" => {} }.to_json
    file = Rack::Test::UploadedFile.new(
      StringIO.new(json_content),
      "application/json",
      original_filename: "missing_metadata.json"
    )

    post manual_analyses_path, params: { json_file: file }

    assert_redirected_to new_analysis_path(tab: "manual")
    assert_equal "JSON에 metadata 키가 필요합니다.", flash[:alert]
  end

  test "POST manual strips markdown code blocks from JSON" do
    json_content = "```json\n" + { "metadata" => { "case_number" => "2024타경999" }, "results" => {} }.to_json + "\n```"
    file = Rack::Test::UploadedFile.new(
      StringIO.new(json_content),
      "application/json",
      original_filename: "markdown_wrapped.json"
    )

    post manual_analyses_path, params: { json_file: file }

    # Should not get a parse error — it should reach the service layer
    assert_not_equal "유효한 JSON 파일이 아닙니다. JSON만 포함된 파일인지 확인해주세요.", flash[:alert]
  end

  test "POST manual rejects json_file larger than 1MB" do
    big_json = Rack::Test::UploadedFile.new(
      StringIO.new("a" * (1.megabyte + 1)),
      "application/json",
      original_filename: "huge.json"
    )

    post manual_analyses_path, params: { json_file: big_json }

    assert_redirected_to new_analysis_path(tab: "manual")
    assert_match(/1MB/, flash[:alert])
  end

  test "POST create rejects oversized PDF (over 5MB)" do
    big_pdf = Rack::Test::UploadedFile.new(
      StringIO.new("%PDF-" + ("a" * 5.megabytes)),
      "application/pdf",
      original_filename: "huge.pdf"
    )

    assert_no_enqueued_jobs only: PdfAnalysisJob do
      post analyses_path, params: { property_id: @property.id, documents: [ big_pdf ] }
    end

    assert_redirected_to new_analysis_path
    assert_match(/5MB/, flash[:alert])
  end

  test "POST create rejects PDF with wrong magic bytes" do
    fake_pdf = Rack::Test::UploadedFile.new(
      StringIO.new("<html>nope</html>"),
      "application/pdf",
      original_filename: "evil.pdf"
    )

    assert_no_enqueued_jobs only: PdfAnalysisJob do
      post analyses_path, params: { property_id: @property.id, documents: [ fake_pdf ] }
    end

    assert_redirected_to new_analysis_path
    assert_match(/PDF 형식/, flash[:alert])
  end

  # IDOR: a logged-in user must NOT be able to enqueue analysis against
  # another user's property by crafting a POST with that property's id.
  test "POST create with another user's property_id is rejected (IDOR)" do
    other_user = users(:guest_two)
    other_property = properties(:basement_villa)
    UserProperty.find_or_create_by!(user: other_user, property: other_property)

    # Sanity: current session user must not own other_property
    assert_not @user.user_properties.exists?(property: other_property)

    pdf = fixture_file_upload("test/fixtures/files/test.pdf", "application/pdf")

    assert_no_enqueued_jobs only: PdfAnalysisJob do
      post analyses_path, params: { property_id: other_property.id, documents: [ pdf ] }
    end

    assert_redirected_to new_analysis_path
    assert flash[:alert].present?
  end

  # B15 / E-44: analysis history view
  test "GET history renders 200 with logs for owned property" do
    log_completed = LlmAnalysisLog.create!(
      property: @property, user: @user,
      system_prompt: "s", user_prompt: "u",
      provider: "anthropic", model: "claude-opus-4",
      status: :completed, executed_at: 1.hour.ago
    )
    log_failed = LlmAnalysisLog.create!(
      property: @property, user: @user,
      system_prompt: "s", user_prompt: "u",
      provider: "openai", model: "gpt-5",
      status: :failed, error_message: "rate limited",
      executed_at: 30.minutes.ago
    )

    get history_analyses_path(property_id: @property.id)

    assert_response :success
    assert_select "body" do
      assert_select "*", text: /anthropic/
      assert_select "*", text: /claude-opus-4/
      assert_select "*", text: /openai/
      assert_select "*", text: /gpt-5/
      assert_select "*", text: /완료/
      assert_select "*", text: /실패/
    end
  end

  test "GET history with empty logs renders empty state" do
    get history_analyses_path(property_id: @property.id)

    assert_response :success
    assert_select "body", text: /분석 이력이 없습니다/
  end

  test "GET history without property_id redirects" do
    get history_analyses_path

    assert_redirected_to properties_path
    assert flash[:alert].present?
  end

  test "GET history with non-existent property_id redirects" do
    get history_analyses_path(property_id: 99999)

    assert_redirected_to properties_path
    assert flash[:alert].present?
  end

  test "GET history with another user's property is rejected (IDOR)" do
    other_user = users(:guest_two)
    other_property = properties(:basement_villa)
    UserProperty.find_or_create_by!(user: other_user, property: other_property)
    LlmAnalysisLog.create!(
      property: other_property, user: other_user,
      system_prompt: "s", user_prompt: "u",
      provider: "anthropic", model: "claude-opus-4",
      status: :completed, executed_at: 1.hour.ago
    )

    assert_not @user.user_properties.exists?(property: other_property)

    get history_analyses_path(property_id: other_property.id)

    assert_redirected_to properties_path
    assert flash[:alert].present?
  end

  test "POST manual with JSON missing case_number shows alert and stays on manual tab" do
    json_content = { "metadata" => { "address" => "test" }, "results" => {} }.to_json
    file = Rack::Test::UploadedFile.new(
      StringIO.new(json_content),
      "application/json",
      original_filename: "no_case.json"
    )

    post manual_analyses_path, params: { json_file: file }

    assert_redirected_to new_analysis_path(tab: "manual")
    assert_equal "metadata.case_number가 필요합니다.", flash[:alert]
  end

  # F-01: rescue 핸들러가 사용자 알림에 raw 예외 메시지를 누설하지 않아야 한다.
  test "POST manual: internal exception does NOT leak e.message to flash, uses incident_id instead" do
    Property.create!(case_number: "2024타경LEAK")
    json_text = { "metadata" => { "case_number" => "2024타경LEAK" }, "results" => {} }.to_json
    sensitive = "PG::UndefinedColumn: column users.secret_internal_field does not exist"

    original = PdfAnalysisService.method(:call)
    PdfAnalysisService.define_singleton_method(:call) { |**_kw| raise StandardError, sensitive }
    begin
      post manual_analyses_path, params: { json_text: json_text }
    ensure
      PdfAnalysisService.define_singleton_method(:call, original)
    end

    assert_redirected_to new_analysis_path(tab: "manual")
    assert_not_nil flash[:alert]
    assert_not_includes flash[:alert].to_s, sensitive
    assert_not_includes flash[:alert].to_s, "secret_internal_field"
    assert_not_includes flash[:alert].to_s, "PG::"
    assert_match(/\b[0-9a-f]{8}\b/, flash[:alert].to_s, "incident id (8 hex chars) should be present")
  end
end
