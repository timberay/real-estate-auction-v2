require "test_helper"

class DataProviderFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:guest)
  end

  test "full flow: visit settings, add key, verify, use in property sync" do
    # 1. Visit settings page
    get settings_data_sources_url
    assert_response :success

    # 2. Add a data.go.kr credential
    post settings_api_credentials_url, params: {
      api_credential: { provider_name: "data_go_kr", api_key: "my-test-key" }
    }
    assert_redirected_to settings_data_sources_url
    cred = @user.api_credentials.last
    assert_equal "data_go_kr", cred.provider_name
    assert_equal "my-test-key", cred.api_key
    assert cred.enabled?

    # Disable and re-enable the credential
    patch settings_api_credential_url(cred), params: {
      api_credential: { enabled: false }
    }
    assert_redirected_to settings_data_sources_url
    cred.reload
    assert_not cred.enabled?

    patch settings_api_credential_url(cred), params: {
      api_credential: { enabled: true }
    }
    assert_redirected_to settings_data_sources_url
    cred.reload
    assert cred.enabled?

    # 3. Verify the credential
    post verify_settings_api_credential_url(cred)
    assert_redirected_to settings_data_sources_url

    # 4. Property sync works with mock mode (default)
    result = PropertyDataSyncService.call(case_number: "2026타경10001", user: @user)
    assert result.court_data.present?
    assert_empty result.errors
  end

  test "consent flow for court_auction" do
    # 1. Create consent credential
    post settings_api_credentials_url, params: {
      api_credential: { provider_name: "court_auction", enabled: true }
    }
    cred = @user.api_credentials.last
    assert_equal "court_auction", cred.provider_name
    assert cred.enabled?
    assert cred.configured?

    # 2. Toggle off
    patch settings_api_credential_url(cred), params: {
      api_credential: { enabled: false }
    }
    assert_not cred.reload.enabled?
    assert_not cred.configured?
  end

  test "credential resolver uses category-aware resolution" do
    @user.api_credentials.create!(provider_name: "codef", api_key: "codef-key", enabled: true)

    ENV["USE_MOCK"] = "false"
    result = CredentialResolver.new(user: @user, category: :registry).resolve
    assert_equal :real, result[:adapter]
    assert_equal :codef, result[:provider]
  ensure
    ENV.delete("USE_MOCK")
  end

  test "missing credential falls back to mock mode in test" do
    # Create a user with no credentials
    new_user = User.create!(email: "test-missing@auction.local", password: "123456")

    # In test mode with USE_MOCK not set to "false", should return mock adapter
    result = CredentialResolver.new(user: new_user, provider_name: "data_go_kr").resolve
    assert_equal :mock, result[:adapter]
  end

  test "consent-based provider without credential falls back to mock mode in test" do
    new_user = User.create!(email: "test-consent@auction.local", password: "123456")

    # In test mode, should return mock adapter even for consent-required providers
    result = CredentialResolver.new(user: new_user, provider_name: "court_auction").resolve
    assert_equal :mock, result[:adapter]
  end

  test "api credential can be destroyed" do
    cred = @user.api_credentials.create!(provider_name: "tilko", api_key: "tilko-key")
    cred_id = cred.id

    delete settings_api_credential_url(cred)
    assert_redirected_to settings_data_sources_url
    assert_not @user.api_credentials.exists?(cred_id)
  end
end
