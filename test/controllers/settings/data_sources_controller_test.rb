require "test_helper"

class Settings::DataSourcesControllerTest < ActionDispatch::IntegrationTest
  test "show displays all providers" do
    get settings_data_sources_path
    assert_response :success
  end
end
