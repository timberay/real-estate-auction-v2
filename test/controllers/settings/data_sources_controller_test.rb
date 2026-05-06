require "test_helper"

class Settings::DataSourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url # bootstrap a guest session (lazy guest creation)
  end

  test "show displays all providers" do
    get settings_data_sources_path
    assert_response :success
  end
end
