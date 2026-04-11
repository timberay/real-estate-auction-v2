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

  test "POST create with Turbo replaces form with progress indicator" do
    pdf = fixture_file_upload("test/fixtures/files/test.pdf", "application/pdf")

    post analyses_path, params: { documents: [ pdf ] },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
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
end
