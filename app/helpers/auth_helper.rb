module AuthHelper
  PROVIDERS = %w[kakao naver google_oauth2].freeze

  LABELS = {
    "kakao"         => "카카오로 계속하기",
    "naver"         => "네이버로 계속하기",
    "google_oauth2" => "Google로 계속하기"
  }.freeze

  def ordered_providers
    last = cookies[:last_provider]
    PROVIDERS.sort_by { |p| matches_last?(p, last) ? 0 : 1 }
  end

  def provider_path(provider)
    "/auth/#{provider}"
  end

  def provider_label(provider)
    LABELS[provider]
  end

  private

  def matches_last?(provider, last)
    return false if last.blank?
    provider == last || (provider == "google_oauth2" && last == "google")
  end
end
