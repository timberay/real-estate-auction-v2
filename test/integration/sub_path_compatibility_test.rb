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

  test "mailer URL helpers include sub-path prefix when env set" do
    original = ENV["RAILS_RELATIVE_URL_ROOT"]
    ENV["RAILS_RELATIVE_URL_ROOT"] = "/real-estate-auction"
    url = Rails.application.routes.url_helpers.root_url(
      host: "example.com",
      script_name: SubPath.prefix
    )
    assert_equal "http://example.com/real-estate-auction/", url
  ensure
    ENV["RAILS_RELATIVE_URL_ROOT"] = original
  end

  test "production.rb mailer default_url_options includes script_name: SubPath.prefix" do
    config_text = File.read(Rails.root.join("config/environments/production.rb"))
    assert_match(
      /config\.action_mailer\.default_url_options\s*=\s*\{[^}]*script_name:\s*SubPath\.prefix/,
      config_text,
      "production.rb mailer default_url_options must include script_name: SubPath.prefix"
    )
  end

  test "development.rb mailer default_url_options includes script_name: SubPath.prefix" do
    config_text = File.read(Rails.root.join("config/environments/development.rb"))
    assert_match(
      /config\.action_mailer\.default_url_options\s*=\s*\{[^}]*script_name:\s*SubPath\.prefix/,
      config_text,
      "development.rb mailer default_url_options must include script_name: SubPath.prefix"
    )
  end
end
