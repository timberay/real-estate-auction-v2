class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_authenticated_user
  before_action :capture_return_to_url
  before_action :touch_last_seen

  helper_method :current_user

  rescue_from ActiveRecord::RecordInvalid, with: :handle_record_invalid
  rescue_from Auth::Error, with: :handle_auth_error
  rescue_from DataProvider::MissingCredentialError, with: :handle_missing_credential
  rescue_from DataProvider::ConsentRequiredError, with: :handle_consent_required
  rescue_from DataProvider::InvalidCredentialError, with: :handle_invalid_credential
  rescue_from DataProvider::ConnectionError, with: :handle_connection_error
  rescue_from DataProvider::RateLimitError, with: :handle_rate_limit
  rescue_from DataProvider::DataNotFoundError, with: :handle_data_not_found
  rescue_from DataProvider::ParseError, with: :handle_parse_error
  rescue_from DataProvider::SiteStructureChangedError, with: :handle_site_changed
  rescue_from DataProvider::ServiceUnavailableError, with: :handle_service_unavailable
  rescue_from DataProvider::Error, with: :handle_generic_provider_error

  private

  # Default before_action: redirects to login if no User row identifies this
  # session. Read-only — never creates a new User, so anonymous bot traffic on
  # protected URLs cannot inflate the users table.
  #
  # Public/landing/login/onboarding entry controllers should
  # `skip_before_action :require_authenticated_user`. Onboarding/OAuth callback
  # additionally use `before_action :ensure_guest_user` to lazily allocate a
  # User row on first meaningful engagement.
  def require_authenticated_user
    return if current_user

    # Persist the original destination so the post-login flow can resume it.
    if request.get? || request.head?
      session[:return_to_url] = request.fullpath unless request.path_info.start_with?("/auth")
    end
    redirect_to auth_login_path, alert: "로그인이 필요합니다"
  end

  # Lazily resolves @current_user, creating a guest if none exists. Use this
  # before any action that writes user-scoped data through `current_user`.
  def ensure_guest_user
    @current_user ||= load_existing_user || create_guest_user!
  end

  # Read-only lookup. Returns nil if no session/cookie identifies a user.
  def load_existing_user
    if session[:user_id] && (user = User.find_by(id: session[:user_id]))
      user
    elsif (uid = cookies.signed[:remember_token]) &&
          (user = User.find_by(id: uid, guest: false))
      session[:user_id] = user.id
      user
    end
  end

  def create_guest_user!
    user = User.create!
    session[:user_id] = user.id
    user
  end

  def current_user
    @current_user ||= load_existing_user
  end

  def capture_return_to_url
    return unless request.get? || request.head?
    return if request.path_info.start_with?("/auth")
    return if request.xhr? || turbo_frame_request?

    session[:return_to_url] = request.fullpath
  end

  LAST_SEEN_TTL_SECONDS = ENV.fetch("LAST_SEEN_TTL_SECONDS", 60).to_i

  def touch_last_seen
    user = current_user
    return unless user
    return if Rails.cache.exist?("last_seen:#{user.id}")

    Rails.cache.write("last_seen:#{user.id}", true, expires_in: LAST_SEEN_TTL_SECONDS.seconds)
    user.update_column(:last_seen_at, Time.current)
  end

  # Global safety net for unhandled validation failures from bang-method writes
  # (update!/save!/create!/destroy!). HTML/Turbo Stream redirects back with a
  # flash alert; JSON returns 422 with structured errors. Per-controller code
  # should still prefer the non-bang form when it wants to re-render the form
  # with the unsaved record — this handler is a last-resort catch.
  def handle_record_invalid(error)
    messages = error.record&.errors&.full_messages || []
    Rails.logger.warn("[RecordInvalid] #{error.record&.class}: #{messages.join(', ')}")
    alert_text = messages.any? ? messages.to_sentence : "입력값이 올바르지 않습니다."

    if request.format.json?
      render json: { errors: messages }, status: :unprocessable_entity
    else
      redirect_back fallback_location: root_path, alert: alert_text
    end
  end

  def handle_auth_error(error)
    Rails.logger.warn("[Auth::Error] #{error.class}: #{error.message}")
    redirect_to auth_login_path, alert: "로그인 중 문제가 발생했습니다. 다시 시도해주세요."
  end

  def handle_missing_credential(_error)
    redirect_to settings_data_sources_path, alert: "이 기능을 사용하려면 API 키를 설정해주세요."
  end

  def handle_consent_required(_error)
    redirect_to settings_data_sources_path, alert: "법원경매 데이터 수집에 동의해주세요."
  end

  def handle_invalid_credential(_error)
    redirect_to settings_data_sources_path, alert: "API 키가 유효하지 않습니다. 확인 후 다시 설정해주세요."
  end

  def handle_connection_error(_error)
    flash.now[:alert] = "외부 서비스에 연결할 수 없습니다. 잠시 후 다시 시도해주세요."
    render "shared/error", status: :service_unavailable
  end

  def handle_rate_limit(_error)
    flash.now[:alert] = "API 호출 한도에 도달했습니다. 잠시 후 다시 시도해주세요."
    render "shared/error", status: :too_many_requests
  end

  def handle_data_not_found(_error)
    flash.now[:notice] = "해당 사건번호의 데이터를 찾을 수 없습니다."
    render "shared/error", status: :not_found
  end

  def handle_parse_error(error)
    Rails.logger.error("[DataProvider::ParseError] #{error.message}")
    flash.now[:alert] = "데이터 형식이 예상과 다릅니다. 관리자에게 문의해주세요."
    render "shared/error", status: :internal_server_error
  end

  def handle_site_changed(error)
    Rails.logger.error("[DataProvider::SiteStructureChangedError] #{error.message}")
    flash.now[:alert] = "법원경매 사이트 구조가 변경되었습니다. 업데이트가 필요합니다."
    render "shared/error", status: :internal_server_error
  end

  def handle_service_unavailable(_error)
    flash.now[:alert] = "외부 서비스가 일시적으로 중단되었습니다. 잠시 후 다시 시도해주세요."
    render "shared/error", status: :service_unavailable
  end

  def handle_generic_provider_error(error)
    Rails.logger.error("[DataProvider::Error] #{error.class}: #{error.message}")
    flash.now[:alert] = "데이터 조회 중 오류가 발생했습니다."
    render "shared/error", status: :internal_server_error
  end
end
