require "test_helper"

class SubPathCompatibilityTest < ActionDispatch::IntegrationTest
  test "CSP report_uri header includes sub-path prefix when env set" do
    original = ENV["RAILS_RELATIVE_URL_ROOT"]
    ENV["RAILS_RELATIVE_URL_ROOT"] = "/real-estate-auction"
    # Re-evaluate the CSP policy block to pick up the new prefix.
    load Rails.root.join("config/initializers/content_security_policy.rb")
    # Clear the cached env_config so the app re-reads the config on the next request.
    Rails.application.instance_variable_set(:@app_env_config, nil)

    get root_path
    header = response.headers["Content-Security-Policy-Report-Only"].to_s
    assert_includes header, "report-uri /real-estate-auction/csp_reports",
      "CSP report_uri must be sub-path-aware; got: #{header}"
  ensure
    ENV["RAILS_RELATIVE_URL_ROOT"] = original
    load Rails.root.join("config/initializers/content_security_policy.rb")
    # Clear the cached env_config to restore the default state.
    Rails.application.instance_variable_set(:@app_env_config, nil)
  end

  test "CSP report_uri is bare /csp_reports when env unset" do
    original = ENV["RAILS_RELATIVE_URL_ROOT"]
    ENV.delete("RAILS_RELATIVE_URL_ROOT")
    load Rails.root.join("config/initializers/content_security_policy.rb")
    # Clear the cached env_config so the app re-reads the config on the next request.
    Rails.application.instance_variable_set(:@app_env_config, nil)

    get root_path
    header = response.headers["Content-Security-Policy-Report-Only"].to_s
    assert_includes header, "report-uri /csp_reports"
  ensure
    ENV["RAILS_RELATIVE_URL_ROOT"] = original
    load Rails.root.join("config/initializers/content_security_policy.rb")
    # Clear the cached env_config to restore the default state.
    Rails.application.instance_variable_set(:@app_env_config, nil)
  end
end
