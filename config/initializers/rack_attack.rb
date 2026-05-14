class Rack::Attack
  AUTH_RATE_LIMIT = ENV.fetch("AUTH_RATE_LIMIT_ATTEMPTS", 10).to_i
  AUTH_RATE_PERIOD = ENV.fetch("AUTH_RATE_LIMIT_PERIOD_SECONDS", 60).to_i.seconds

  ANALYSES_PROMPT_RATE_LIMIT = ENV.fetch("ANALYSES_PROMPT_RATE_LIMIT_ATTEMPTS", 60).to_i
  ANALYSES_PROMPT_RATE_PERIOD = ENV.fetch("ANALYSES_PROMPT_RATE_LIMIT_PERIOD_SECONDS", 60).to_i.seconds

  # W0-3.3 — progressive backoff via tiered hour-window throttles. The minute
  # tier is the front line; the hour tier catches sustained abuse that paces
  # itself just under the per-minute cap.
  AUTH_HOUR_RATE_LIMIT = ENV.fetch("AUTH_HOUR_RATE_LIMIT_ATTEMPTS", 100).to_i
  AUTH_HOUR_RATE_PERIOD = ENV.fetch("AUTH_HOUR_RATE_LIMIT_PERIOD_SECONDS", 3600).to_i.seconds

  ANALYSES_PROMPT_HOUR_RATE_LIMIT = ENV.fetch("ANALYSES_PROMPT_HOUR_RATE_LIMIT_ATTEMPTS", 600).to_i
  ANALYSES_PROMPT_HOUR_RATE_PERIOD = ENV.fetch("ANALYSES_PROMPT_HOUR_RATE_LIMIT_PERIOD_SECONDS", 3600).to_i.seconds

  # W0-3.3 — env-driven static IP denylist. BLOCKED_IPS is a comma-separated
  # list (e.g. "1.2.3.4,5.6.7.8"). Empty by default. Lazy-memoized so tests
  # can swap it without touching ENV.
  def self.blocked_ips
    @blocked_ips ||= ENV.fetch("BLOCKED_IPS", "").split(",").map(&:strip).reject(&:blank?).freeze
  end

  blocklist("blocked_ips") do |req|
    blocked_ips.include?(req.ip)
  end

  throttle("auth:ip", limit: AUTH_RATE_LIMIT, period: AUTH_RATE_PERIOD) do |req|
    req.ip if req.path_info.start_with?("/auth/") && req.post?
  end

  throttle("auth:ip:hour", limit: AUTH_HOUR_RATE_LIMIT, period: AUTH_HOUR_RATE_PERIOD) do |req|
    req.ip if req.path_info.start_with?("/auth/") && req.post?
  end

  # T4.7 / C31: throttle the LLM-prompt endpoint per IP. The body is the
  # full system+user prompt, identical on every request — scraping it in a
  # tight loop is the obvious abuse pattern.
  throttle("analyses_prompt:ip", limit: ANALYSES_PROMPT_RATE_LIMIT, period: ANALYSES_PROMPT_RATE_PERIOD) do |req|
    req.ip if req.path_info.end_with?("/analyses/prompt") && req.get?
  end

  throttle("analyses_prompt:ip:hour", limit: ANALYSES_PROMPT_HOUR_RATE_LIMIT, period: ANALYSES_PROMPT_HOUR_RATE_PERIOD) do |req|
    req.ip if req.path_info.end_with?("/analyses/prompt") && req.get?
  end

  self.throttled_responder = ->(_request) {
    [ 429, { "Content-Type" => "text/plain" }, [ "Too many requests. Try again later." ] ]
  }
end
