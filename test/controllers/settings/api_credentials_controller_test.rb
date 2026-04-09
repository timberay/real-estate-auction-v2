require "test_helper"

class Settings::ApiCredentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_path  # ensure guest session
    @user = User.find(session[:user_id])
  end

  test "create saves credential" do
    assert_difference "ApiCredential.count", 1 do
      post settings_api_credentials_path, params: {
        api_credential: { provider_name: "data_go_kr", api_key: "test-key" }
      }
    end
    assert_redirected_to settings_data_sources_path
  end

  test "update changes api_key" do
    cred = ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "old")
    patch settings_api_credential_path(cred), params: {
      api_credential: { api_key: "new-key" }
    }
    assert_redirected_to settings_data_sources_path
    assert_equal "new-key", cred.reload.api_key
  end

  test "destroy removes credential" do
    cred = ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "key")
    assert_difference "ApiCredential.count", -1 do
      delete settings_api_credential_path(cred)
    end
  end

  test "consent toggle creates court_auction credential" do
    post settings_api_credentials_path, params: {
      api_credential: { provider_name: "court_auction", enabled: true }
    }
    cred = ApiCredential.last
    assert_equal "court_auction", cred.provider_name
    assert cred.enabled?
  end
end
