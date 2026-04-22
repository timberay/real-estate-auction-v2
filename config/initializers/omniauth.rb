Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.dig(:google, :client_id),
    Rails.application.credentials.dig(:google, :client_secret),
    scope: "email,profile"

  provider :naver,
    Rails.application.credentials.dig(:naver, :client_id),
    Rails.application.credentials.dig(:naver, :client_secret),
    scope: "name email profile_image"

  provider :kakao,
    Rails.application.credentials.dig(:kakao, :client_id),
    Rails.application.credentials.dig(:kakao, :client_secret),
    scope: "account_email profile_nickname profile_image"
end

OmniAuth.config.on_failure = proc { |env| Auth::OmniauthCallbacksController.action(:failure).call(env) }

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true

if Rails.env.test?
  OmniAuth.config.test_mode = true
end
