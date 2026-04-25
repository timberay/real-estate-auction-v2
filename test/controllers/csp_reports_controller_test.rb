require "test_helper"

class CspReportsControllerTest < ActionDispatch::IntegrationTest
  test "POST returns 204 and logs the raw payload with csp.violation tag" do
    captured = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new(captured))

    payload = '{"csp-report":{"document-uri":"http://example/x","violated-directive":"script-src"}}'
    post "/csp_reports", params: payload, headers: { "CONTENT_TYPE" => "application/csp-report" }

    assert_response :no_content
    assert_match "csp.violation", captured.string
    assert_match "violated-directive", captured.string
  ensure
    Rails.logger = original if original
  end
end
