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

  test "capture_return_to_url skips /auth under any prefix" do
    # Simulate sub-path by mocking request.script_name; we exercise the controller filter directly.
    controller = ApplicationController.new
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["SCRIPT_NAME"] = "/real-estate-auction"
    env["PATH_INFO"] = "/auth/login"
    controller.request = ActionDispatch::Request.new(env)
    controller.send(:instance_variable_set, :@_session_for_test, {})
    # Stub session helper
    controller.define_singleton_method(:session) { @_session_for_test }
    controller.send(:capture_return_to_url)
    assert_nil controller.session[:return_to_url],
      "should not capture /auth/* even when sub-path makes request.path /<prefix>/auth/login"
  end

  test "capture_return_to_url stores non-/auth path under sub-path" do
    controller = ApplicationController.new
    env = Rack::MockRequest.env_for("/", method: "GET")
    env["SCRIPT_NAME"] = "/real-estate-auction"
    env["PATH_INFO"] = "/properties"
    env["QUERY_STRING"] = ""
    controller.request = ActionDispatch::Request.new(env)
    controller.send(:instance_variable_set, :@_session_for_test, {})
    controller.define_singleton_method(:session) { @_session_for_test }
    controller.define_singleton_method(:turbo_frame_request?) { false }
    controller.send(:capture_return_to_url)
    assert_equal "/real-estate-auction/properties", controller.session[:return_to_url]
  end

  test "handle_auth_error redirect Location includes script_name" do
    # Verify the source uses the named helper.
    source = File.read(Rails.root.join("app/controllers/application_controller.rb"))
    assert_match(/redirect_to auth_login_path/, source)
    refute_match(%r{redirect_to "/auth/login"}, source)
  end

  test "omniauth failure redirect Location uses named helper" do
    source = File.read(Rails.root.join("app/controllers/auth/omniauth_callbacks_controller.rb"))
    assert_match(/redirect_to auth_login_path/, source)
    refute_match(%r{redirect_to "/auth/login"}, source)
  end
end
