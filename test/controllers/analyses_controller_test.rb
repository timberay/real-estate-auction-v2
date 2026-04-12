require "test_helper"

class AnalysesControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url # creates guest session
    @user = User.find_by(email: "guest@auction.local")
  end

  test "GET new renders upload form" do
    get new_analysis_path
    assert_response :success
    assert_select "input[type=file]"
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
  test "GET prompt downloads markdown file" do
    get prompt_analyses_path

    assert_response :success
    assert_equal "text/markdown", response.content_type
    assert_match /attachment/, response.headers["Content-Disposition"]
    assert_match /auction-analysis-prompt\.md/, response.headers["Content-Disposition"]
    assert_includes response.body, "부동산 경매 AI 분석 프롬프트"
    assert_includes response.body, "시스템 프롬프트"
    assert_includes response.body, "사용자 프롬프트"
    assert_includes response.body, "기대 응답 형식"
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

  test "POST manual without JSON file shows alert" do
    post manual_analyses_path, params: {}

    assert_redirected_to new_analysis_path
    assert_equal "JSON 파일을 업로드해주세요.", flash[:alert]
  end

  test "POST manual with invalid JSON shows alert" do
    invalid_file = Rack::Test::UploadedFile.new(
      StringIO.new("this is not json"),
      "application/json",
      original_filename: "bad.json"
    )

    post manual_analyses_path, params: { json_file: invalid_file }

    assert_redirected_to new_analysis_path
    assert_equal "유효한 JSON 파일이 아닙니다.", flash[:alert]
  end

  test "POST manual with JSON missing metadata key shows alert" do
    json_content = { "results" => {} }.to_json
    file = Rack::Test::UploadedFile.new(
      StringIO.new(json_content),
      "application/json",
      original_filename: "missing_metadata.json"
    )

    post manual_analyses_path, params: { json_file: file }

    assert_redirected_to new_analysis_path
    assert_equal "JSON에 metadata 키가 필요합니다.", flash[:alert]
  end

  test "POST manual with JSON missing case_number shows alert" do
    json_content = { "metadata" => { "address" => "test" }, "results" => {} }.to_json
    file = Rack::Test::UploadedFile.new(
      StringIO.new(json_content),
      "application/json",
      original_filename: "no_case.json"
    )

    post manual_analyses_path, params: { json_file: file }

    assert_redirected_to new_analysis_path
    assert_equal "metadata.case_number가 필요합니다.", flash[:alert]
  end
end
