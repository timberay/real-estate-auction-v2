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

  # --- W0-3.3: progressive backoff (tiered throttles) ---

  test "auth:ip:hour tier-2 throttle is registered" do
    assert Rack::Attack.throttles.key?("auth:ip:hour"),
      "expected hour-window throttle to exist for progressive backoff on /auth/*"
  end

  test "auth:ip:hour tier-2 has a larger budget but longer window than minute tier" do
    minute_tier = Rack::Attack.throttles["auth:ip"]
    hour_tier = Rack::Attack.throttles["auth:ip:hour"]
    assert_operator hour_tier.limit, :>, minute_tier.limit, "hour-tier budget must exceed minute-tier"
    assert_operator hour_tier.period, :>, minute_tier.period, "hour-tier window must exceed minute-tier"
  end

  test "auth:ip:hour throttle triggers on POST to /auth/*" do
    req = make_request(script_name: "", path_info: "/auth/login", method: "POST")
    block = Rack::Attack.throttles["auth:ip:hour"].block
    assert_equal "1.2.3.4", block.call(req)
  end

  test "auth:ip:hour throttle does not trigger on GET" do
    req = make_request(script_name: "", path_info: "/auth/login", method: "GET")
    assert_nil Rack::Attack.throttles["auth:ip:hour"].block.call(req)
  end

  test "analyses_prompt:ip:hour tier-2 throttle is registered" do
    assert Rack::Attack.throttles.key?("analyses_prompt:ip:hour"),
      "expected hour-window throttle to exist for progressive backoff on /analyses/prompt"
  end

  # --- W0-3.3: static IP denylist (env-driven) ---

  test "blocked_ips blocklist is registered" do
    assert Rack::Attack.blocklists.key?("blocked_ips"),
      "expected blocked_ips static denylist to be configured"
  end

  test "blocked_ips returns an Array (lazy-parsed from BLOCKED_IPS env)" do
    assert_respond_to Rack::Attack, :blocked_ips
    assert_kind_of Array, Rack::Attack.blocked_ips
  end

  test "blocked_ips blocklist matches when ip is in the configured set" do
    with_blocked_ips([ "9.9.9.9" ]) do
      req = make_request(script_name: "", path_info: "/properties", method: "GET", ip: "9.9.9.9")
      block = Rack::Attack.blocklists["blocked_ips"].block
      assert block.call(req), "expected request from blocked IP to match denylist"
    end
  end

  test "blocked_ips blocklist does not match when ip is not in the configured set" do
    with_blocked_ips([ "9.9.9.9" ]) do
      req = make_request(script_name: "", path_info: "/properties", method: "GET", ip: "1.1.1.1")
      block = Rack::Attack.blocklists["blocked_ips"].block
      refute block.call(req)
    end
  end

  private

  # The blocked_ips list is memoized on the class. Swap the ivar in/out so
  # tests can configure their own set without touching ENV.
  def with_blocked_ips(ips)
    previous = Rack::Attack.instance_variable_get(:@blocked_ips)
    Rack::Attack.instance_variable_set(:@blocked_ips, ips.freeze)
    yield
  ensure
    Rack::Attack.instance_variable_set(:@blocked_ips, previous)
  end
end
