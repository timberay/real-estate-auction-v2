class CredentialResolver
  def initialize(user:, provider_name: nil, category: nil)
    @user = user
    @provider_name = provider_name&.to_sym
    @category = category&.to_sym
    raise ArgumentError, "provider_name or category required" unless @provider_name || @category
  end

  def resolve
    return { adapter: :mock } if mock_mode?

    credential = find_credential
    if credential&.configured?
      {
        adapter: :real,
        provider: credential.provider_name.to_sym,
        api_key: credential.api_key,
        api_secret: credential.api_secret
      }
    elsif production?
      raise error_for_provider
    else
      { adapter: :mock }
    end
  end

  private

  def find_credential
    return nil unless @user

    if @provider_name
      @user.api_credentials.active.for_provider(@provider_name)
    else
      providers_in_category = ApiCredential::PROVIDERS
        .select { |_, v| v[:category] == @category }
        .keys.map(&:to_s)
      @user.api_credentials.active
        .where(provider_name: providers_in_category)
        .order(:created_at)
        .first
    end
  end

  def mock_mode?
    ENV["USE_MOCK"] != "false"
  end

  def production?
    Rails.env.production?
  end

  def error_for_provider
    config = if @provider_name
      ApiCredential::PROVIDERS[@provider_name]
    else
      ApiCredential::PROVIDERS.values.find { |v| v[:category] == @category }
    end

    if config&.dig(:requires_consent)
      DataProvider::ConsentRequiredError.new("법원경매 데이터 수집에 동의해주세요.")
    else
      DataProvider::MissingCredentialError.new("#{config&.dig(:name_ko)} API 키를 설정해주세요.")
    end
  end
end
