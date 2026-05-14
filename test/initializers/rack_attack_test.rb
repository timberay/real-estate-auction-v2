require "test_helper"
require "rack/attack"

class RackAttackThrottleTest < ActiveSupport::TestCase
  def make_request(script_name:, path_info:, method: "POST", ip: "1.2.3.4")
    env = Rack::MockRequest.env_for(
      "http://example.com#{script_name}#{path_info}",
      method: method,
      "REMOTE_ADDR" => ip
    )
    env["SCRIPT_NAME"] = script_name
    env["PATH_INFO"] = path_info
    Rack::Attack::Request.new(env)
  end

  def call_throttle_block(req)
    # Get the throttle block and call it with the request
    throttle = Rack::Attack.throttles["auth:ip"]
    throttle.block.call(req)
  end

  def call_prompt_throttle_block(req)
    throttle = Rack::Attack.throttles["analyses_prompt:ip"]
    throttle.block.call(req)
  end

  test "auth:ip throttle triggers on POST to /auth/* under sub-path" do
    req = make_request(script_name: "/real-estate-auction", path_info: "/auth/login", method: "POST")
    discriminator = call_throttle_block(req)
    assert_equal "1.2.3.4", discriminator,
      "auth throttle must trigger on /auth/* under sub-path; got #{discriminator.inspect}"
  end

  test "auth:ip throttle triggers on POST to /auth/* without sub-path" do
    req = make_request(script_name: "", path_info: "/auth/login", method: "POST")
    discriminator = call_throttle_block(req)
    assert_equal "1.2.3.4", discriminator
  end

  test "auth:ip throttle does not trigger on non-/auth paths" do
    req = make_request(script_name: "/real-estate-auction", path_info: "/properties", method: "POST")
    discriminator = call_throttle_block(req)
    assert_nil discriminator
  end

  test "auth:ip throttle does not trigger on GET" do
    req = make_request(script_name: "/real-estate-auction", path_info: "/auth/login", method: "GET")
    discriminator = call_throttle_block(req)
    assert_nil discriminator
  end

  # --- analyses_prompt:ip (T4.7 / C31) ---

  test "analyses_prompt:ip throttle is registered" do
    assert Rack::Attack.throttles.key?("analyses_prompt:ip"),
      "expected analyses_prompt:ip throttle to be configured for the prompt endpoint"
  end

  test "analyses_prompt:ip throttle triggers on GET to /analyses/prompt" do
    req = make_request(script_name: "", path_info: "/analyses/prompt", method: "GET")
    discriminator = call_prompt_throttle_block(req)
    assert_equal "1.2.3.4", discriminator,
      "analyses_prompt throttle must trigger on GET /analyses/prompt; got #{discriminator.inspect}"
  end

  test "analyses_prompt:ip throttle triggers under sub-path mount" do
    req = make_request(script_name: "/real-estate-auction", path_info: "/analyses/prompt", method: "GET")
    discriminator = call_prompt_throttle_block(req)
    assert_equal "1.2.3.4", discriminator
  end

  test "analyses_prompt:ip throttle does not trigger on POST" do
    req = make_request(script_name: "", path_info: "/analyses/prompt", method: "POST")
    discriminator = call_prompt_throttle_block(req)
    assert_nil discriminator
  end

  test "analyses_prompt:ip throttle does not trigger on unrelated paths" do
    req = make_request(script_name: "", path_info: "/properties", method: "GET")
    discriminator = call_prompt_throttle_block(req)
    assert_nil discriminator
  end
end
