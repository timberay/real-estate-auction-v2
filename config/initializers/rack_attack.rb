class Rack::Attack
  AUTH_RATE_LIMIT = ENV.fetch("AUTH_RATE_LIMIT_ATTEMPTS", 10).to_i
  AUTH_RATE_PERIOD = ENV.fetch("AUTH_RATE_LIMIT_PERIOD_SECONDS", 60).to_i.seconds

  throttle("auth:ip", limit: AUTH_RATE_LIMIT, period: AUTH_RATE_PERIOD) do |req|
    req.ip if req.path_info.start_with?("/auth/") && req.post?
  end

  self.throttled_responder = ->(_request) {
    [ 429, { "Content-Type" => "text/plain" }, [ "Too many login attempts. Try again later." ] ]
  }
end
