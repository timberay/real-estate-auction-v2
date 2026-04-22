class Auth::OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :create ]

  ADAPTERS = {
    "google_oauth2" => Auth::GoogleAdapter,
    "kakao"         => Auth::KakaoAdapter,
    "naver"         => Auth::NaverAdapter
  }.freeze

  def create
    adapter_class = ADAPTERS[request.env["omniauth.auth"]["provider"]]
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
    code = params[:message].to_s
    flash[:alert] = failure_message(code)
    redirect_to "/auth/login"
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
