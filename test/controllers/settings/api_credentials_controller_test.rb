require "test_helper"

class Settings::ApiCredentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_path  # ensure guest session
    @user = User.find(session[:user_id])
  end

  test "consent toggle creates court_auction credential" do
    assert_difference "ApiCredential.count", 1 do
      post settings_api_credentials_path, params: {
        api_credential: { provider_name: "court_auction", enabled: true }
      }
    end
    assert_redirected_to settings_data_sources_path
    cred = ApiCredential.last
    assert_equal "court_auction", cred.provider_name
    assert cred.enabled?
  end

  test "consent toggle updates court_auction credential" do
    cred = ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: false)
    patch settings_api_credential_path(cred), params: {
      api_credential: { enabled: true }
    }
    assert_redirected_to settings_data_sources_path
    assert cred.reload.enabled?
  end

  test "destroy removes credential" do
    cred = ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: true)
    assert_difference "ApiCredential.count", -1 do
      delete settings_api_credential_path(cred)
    end
  end
end
