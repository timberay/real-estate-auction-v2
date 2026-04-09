module DataProviderTestHelper
  def with_mock_mode(&block)
    original = ENV["USE_MOCK"]
    ENV["USE_MOCK"] = "true"
    yield
  ensure
    ENV["USE_MOCK"] = original
  end

  def with_real_mode(&block)
    original = ENV["USE_MOCK"]
    ENV["USE_MOCK"] = "false"
    yield
  ensure
    ENV["USE_MOCK"] = original
  end

  def create_credential(user:, provider:, api_key: "test-key-123", enabled: true)
    ApiCredential.create!(
      user: user,
      provider_name: provider.to_s,
      api_key: api_key,
      enabled: enabled
    )
  end
end
