class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :ensure_current_user
  before_action :capture_return_to_url
  before_action :touch_last_seen

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

  def ensure_current_user
    if session[:user_id] && (user = User.find_by(id: session[:user_id]))
      @current_user = user
    else
      @current_user = User.create!
      session[:user_id] = @current_user.id
    end
  end

  def capture_return_to_url
    return unless request.get?
    return if request.path.start_with?("/auth")
    return if request.xhr? || turbo_frame_request?

    session[:return_to_url] = request.fullpath
  end

  def touch_last_seen
    return unless @current_user
    return if Rails.cache.exist?("last_seen:#{@current_user.id}")

    Rails.cache.write("last_seen:#{@current_user.id}", true, expires_in: 1.minute)
    @current_user.update_column(:last_seen_at, Time.current)
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
  helper_method :current_user

  def handle_auth_error(error)
    Rails.logger.warn("[Auth::Error] #{error.class}: #{error.message}")
    redirect_to "/auth/login", alert: "로그인 중 문제가 발생했습니다. 다시 시도해주세요."
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
