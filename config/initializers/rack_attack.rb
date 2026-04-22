class Rack::Attack
  throttle("auth:ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/auth/") && req.post?
  end

  self.throttled_responder = ->(_request) {
    [ 429, { "Content-Type" => "text/plain" }, [ "Too many login attempts. Try again later." ] ]
  }
end
