class Auth::OmniauthCallbacksController < ApplicationController
  skip_before_action :require_authenticated_user
  skip_before_action :verify_authenticity_token, only: [ :create ]
  prepend_before_action :ensure_guest_user, only: [ :create ]

  ADAPTERS = {
    "google_oauth2" => Auth::GoogleAdapter,
    "kakao"         => Auth::KakaoAdapter,
    "naver"         => Auth::NaverAdapter
  }.freeze

  def create
    adapter_class = ADAPTERS[request.env["omniauth.auth"]["provider"].to_s]
    raise Auth::ProviderError, "unknown provider" unless adapter_class

    profile = adapter_class.new(request.env["omniauth.auth"]).to_profile
    return_to = session.delete(:return_to_url) || root_path
    pending = session.delete(:pending_post_action)

    target_user = SessionCreator.new(current_guest: current_user, profile: profile).call

    reset_session
    session[:user_id] = target_user.id
    cookies.permanent.signed[:remember_token] = { value: target_user.id, httponly: true, same_site: :lax }
    cookies.permanent[:last_provider] = profile.provider

    notice = "환영합니다, #{target_user.name}님"
    notice = "#{notice} — #{pending}를 다시 눌러주세요." if pending
    flash[:notice] = notice
    redirect_to return_to
  end

  def failure
    error_type = params[:message].presence || request.env["omniauth.error.type"]&.to_s.presence || ""
    if (error = request.env["omniauth.error"])
      Rails.logger.error("[OmniAuth Failure] strategy=#{request.env['omniauth.error.strategy']&.name} type=#{error_type} #{error.class}: #{error.message}")
      Rails.logger.error(error.backtrace.first(10).join("\n")) if error.backtrace
    else
      Rails.logger.error("[OmniAuth Failure] type=#{error_type} (no exception in env)")
    end
    flash[:alert] = failure_message(error_type)
    redirect_to auth_login_path
  end

  private

  def failure_message(code)
    case code
    when "access_denied"       then "로그인이 취소되었습니다."
    when "timeout"             then "응답 지연입니다. 잠시 후 다시 시도해주세요."
    when "csrf_detected"       then "보안 검증에 실패했습니다. 다시 시도해주세요."
    when "invalid_credentials" then "로그인에 실패했습니다."
    else                            "로그인 중 문제가 발생했습니다."
    end
  end
end
