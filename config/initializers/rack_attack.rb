class Rack::Attack
  AUTH_RATE_LIMIT = ENV.fetch("AUTH_RATE_LIMIT_ATTEMPTS", 10).to_i
  AUTH_RATE_PERIOD = ENV.fetch("AUTH_RATE_LIMIT_PERIOD_SECONDS", 60).to_i.seconds

  ANALYSES_PROMPT_RATE_LIMIT = ENV.fetch("ANALYSES_PROMPT_RATE_LIMIT_ATTEMPTS", 60).to_i
  ANALYSES_PROMPT_RATE_PERIOD = ENV.fetch("ANALYSES_PROMPT_RATE_LIMIT_PERIOD_SECONDS", 60).to_i.seconds

  throttle("auth:ip", limit: AUTH_RATE_LIMIT, period: AUTH_RATE_PERIOD) do |req|
    req.ip if req.path_info.start_with?("/auth/") && req.post?
  end

  # T4.7 / C31: throttle the LLM-prompt endpoint per IP. The body is the
  # full system+user prompt, identical on every request — scraping it in a
  # tight loop is the obvious abuse pattern.
  throttle("analyses_prompt:ip", limit: ANALYSES_PROMPT_RATE_LIMIT, period: ANALYSES_PROMPT_RATE_PERIOD) do |req|
    req.ip if req.path_info.end_with?("/analyses/prompt") && req.get?
  end

  self.throttled_responder = ->(_request) {
    [ 429, { "Content-Type" => "text/plain" }, [ "Too many requests. Try again later." ] ]
  }
end
