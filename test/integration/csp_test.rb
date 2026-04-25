require "test_helper"

class CspTest < ActionDispatch::IntegrationTest
  test "response carries Content-Security-Policy-Report-Only header" do
    get "/auth/login"
    header = response.headers["Content-Security-Policy-Report-Only"]
    assert header.present?, "Report-Only header missing"
    assert_match(/default-src 'self'/, header)
    assert_match(%r{report-uri /csp_reports}, header)
  end

  test "nonce is injected into the header and the dark-mode script" do
    get "/auth/login"
    header = response.headers["Content-Security-Policy-Report-Only"]
    nonce = header[/script-src[^;]*'nonce-([^']+)'/, 1]
    assert nonce.present?, "script-src nonce missing from header"
    assert_match(/<script nonce="#{Regexp.escape(nonce)}">/, response.body)
  end

  test "no enforcement header while in Report-Only mode" do
    get "/auth/login"
    assert_nil response.headers["Content-Security-Policy"]
  end
end
