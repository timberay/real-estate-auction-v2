require "test_helper"

class AnalysesControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url # creates guest session
    @user = User.find(session[:user_id])
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

    post analyses_path, params: { documents: [ pdf ] },
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

    post analyses_path, params: { documents: [ pdf ] }

    assert_redirected_to new_analysis_path
    assert_equal "분석이 시작되었습니다.", flash[:notice]
  end

  test "POST create without documents shows alert" do
    post analyses_path, params: {}

    assert_redirected_to new_analysis_path
    assert flash[:alert].present?
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
    json_file = fixture_file_upload("test/fixtures/files/ai_inspection_response.json", "application/json")

    post manual_analyses_path, params: { json_file: json_file }

    property = Property.find_by(case_number: "2024타경12345")
    assert_not_nil property
    assert_redirected_to edit_property_inspections_tab_path(property, tab_key: "rights_analysis")
    assert_equal "분석 결과가 저장되었습니다.", flash[:notice]
  end

  test "POST manual without JSON file shows alert and stays on manual tab" do
    post manual_analyses_path, params: {}

    assert_redirected_to new_analysis_path(tab: "manual")
    assert_equal "JSON 파일을 업로드하거나 텍스트를 붙여넣어주세요.", flash[:alert]
  end

  test "POST manual with json_text param processes pasted JSON" do
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
end
